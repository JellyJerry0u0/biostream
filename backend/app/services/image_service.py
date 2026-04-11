import io
import os
from datetime import date
from pathlib import Path
from typing import Optional, Dict, Any, Tuple
from urllib.parse import urlparse

import httpx
from sqlalchemy.orm import Session

from app.models import Lifestyle
from app.database import SessionLocal
from app.services.gpu_image_client import GPUImageClient

'''
.env루트 (추가해야함)
IMAGE_GENERATION_API_URL=http://your-gpu-ip:8000/generate
IMAGE_GENERATION_API_KEY=your-secret-key
'''

# GPU /skin-edit — 점수 외 고정 SD 파라미터 (GPU app.py 가 guidance 등 상한으로 클램프할 수 있음)
GPU_SKIN_EDIT_STRENGTH = 0.1
GPU_SKIN_EDIT_GUIDANCE_SCALE = 15.0
GPU_SKIN_EDIT_NUM_INFERENCE_STEPS = 35
GPU_SKIN_EDIT_SEED = 1234


def _image_preprocess_mode() -> str:
    """
    gpu_match: GPU 서버와 동일
      — /generate: preprocess_for_fading (정사각 중앙 크롭 → BICUBIC size×size)
      — /skin-edit: _preprocess_square_canvas (비율 유지 → target 정사각 흰 캔버스, LANCZOS)
    diffusers_vae: VaeImageProcessor 스타일 (8배수 등).
    legacy_cover: 예전 cover + 원본 줌.
    """
    raw = os.getenv("IMAGE_PREPROCESS_MODE", "gpu_match").strip().lower()
    if raw in ("legacy", "legacy_cover", "cover"):
        return "legacy_cover"
    if raw in ("diffusers", "diffusers_vae", "vae"):
        return "diffusers_vae"
    return "gpu_match"


def _fading_preprocess_size() -> int:
    raw = os.getenv("IMAGE_PREPROCESS_FADING_SIZE", "512").strip()
    try:
        v = int(raw)
        return v if v >= 64 else 512
    except ValueError:
        return 512


def _preprocess_for_fading_pil(im: "Image.Image", size: int) -> "Image.Image":
    """GPU preprocess_for_fading 와 동일: RGB → 짧은 변 기준 정사각 중앙 크롭 → BICUBIC size×size."""
    from PIL import Image

    im = im.convert("RGB")
    w, h = im.size
    if h < w:
        left = (w - h) // 2
        im = im.crop((left, 0, left + h, h))
    elif w < h:
        top = (h - w) // 2
        im = im.crop((0, top, w, top + w))
    return im.resize((size, size), Image.Resampling.BICUBIC)


def _preprocess_sdxl_square_canvas_pil(im: "Image.Image", target: int) -> "Image.Image":
    """GPU _preprocess_square_canvas: 비율 유지해 target 안에 맞춘 뒤 흰 배경 정사각 캔버스 중앙."""
    from PIL import Image

    im = im.convert("RGB")
    w, h = im.size
    if w <= 0 or h <= 0:
        return Image.new("RGB", (target, target), (255, 255, 255))
    scale = min(target / w, target / h)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    resized = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (target, target), (255, 255, 255))
    canvas.paste(resized, ((target - nw) // 2, (target - nh) // 2))
    return canvas


def _preprocess_vae_scale_factor() -> int:
    raw = os.getenv("IMAGE_PREPROCESS_VAE_SCALE", "8").strip()
    try:
        v = int(raw)
        return 8 if v < 2 else min(v, 128)
    except ValueError:
        return 8


def _preprocess_max_side_optional() -> Optional[int]:
    """비우면 max_side 축소 없음(순수 diffusers floor-multiple 리사이즈만)."""
    raw = os.getenv("IMAGE_PREPROCESS_MAX_SIDE", "").strip().lower()
    if not raw or raw in ("0", "off", "none"):
        return None
    try:
        v = int(raw)
        return v if v >= 32 else None
    except ValueError:
        return None


def _scale_pil_max_long_edge(im: "Image.Image", max_side: int) -> "Image.Image":
    from PIL import Image

    w, h = im.size
    m = max(w, h)
    if m <= max_side:
        return im
    s = max_side / m
    nw = max(1, int(round(w * s)))
    nh = max(1, int(round(h * s)))
    return im.resize((nw, nh), Image.Resampling.LANCZOS)


def _diffusers_vae_spatial_preprocess_rgb(im: "Image.Image") -> Tuple["Image.Image", int, int]:
    """
    diffusers VaeImageProcessor: get_default_height_width (배수 정렬) + resize(default)=Lanczos (W,H).
    SDXL/img2img 가 PIL 을 넣을 때와 같은 픽셀 그리드(정렬된 W×H)를 맞춘다.
    """
    from PIL import Image

    im = im.convert("RGB")
    max_side = _preprocess_max_side_optional()
    if max_side is not None:
        im = _scale_pil_max_long_edge(im, max_side)
    f = _preprocess_vae_scale_factor()
    w, h = im.size
    w2 = max(f, w - (w % f))
    h2 = max(f, h - (h % f))
    if (w2, h2) != (w, h):
        im = im.resize((w2, h2), Image.Resampling.LANCZOS)
    return im, w2, h2


def _compare_center_zoom() -> float:
    """
    반반 비교용: 생성물은 GPU에서 이미 프레이밍되므로 건드리지 않고,
    디스크 원본만 추가 중앙 줌(가로·세로 각각 이 비율만큼만 남김)으로 맞출 때 사용.
    1.0 = 원본도 추가 크롭 없음, 0.75 = 원본 가운데 75%만 사용.
    """
    raw = os.getenv("IMAGE_COMPARE_CENTER_ZOOM", "0.78").strip()
    try:
        z = float(raw)
        return max(0.45, min(1.0, z))
    except ValueError:
        return 0.78


def _apply_center_zoom_square(im: "Image.Image", zoom: float) -> "Image.Image":
    """가로·세로 동일 비율로 중앙만 남김 (원본 비교용 추가 크롭)."""
    if zoom >= 0.999:
        return im
    w, h = im.size
    nw = max(1, int(round(w * zoom)))
    nh = max(1, int(round(h * zoom)))
    left = max(0, (w - nw) // 2)
    top = max(0, (h - nh) // 2)
    return im.crop((left, top, left + nw, top + nh))


def _skin_edit_max_side() -> Optional[int]:
    """
    비우거나 omit/none/off/0 이면 multipart 에 max_side 를 넣지 않음 (/docs 에서 필드 비운 것과 유사, 레터박스 완화).
    양의 정수면 해당 값 전송 (예: 1024).
    """
    raw = os.getenv("IMAGE_GENERATION_SKIN_EDIT_MAX_SIDE", "").strip().lower()
    if not raw or raw in ("omit", "none", "off", "0"):
        return None
    try:
        v = int(raw)
        return v if v > 0 else None
    except ValueError:
        return None


def _sdxl_canvas_target() -> int:
    """skin-edit 정사각 캔버스 한 변. multipart max_side 가 있으면 그것과 맞춤."""
    ms = _skin_edit_max_side()
    if ms is not None:
        return ms
    raw = os.getenv("IMAGE_PREPROCESS_SDXL_CANVAS", "1024").strip()
    try:
        v = int(raw)
        return v if v >= 256 else 1024
    except ValueError:
        return 1024


def _pil_upright_rgb_from_bytes(image_bytes: bytes) -> "Image.Image":
    from PIL import Image, ImageOps

    im = Image.open(io.BytesIO(image_bytes))
    im = ImageOps.exif_transpose(im)
    if im.mode in ("RGBA", "P"):
        bg = Image.new("RGB", im.size, (255, 255, 255))
        if im.mode == "P":
            im = im.convert("RGBA")
        bg.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
        im = bg
    elif im.mode != "RGB":
        im = im.convert("RGB")
    return im


def _upright_jpeg_bytes_for_gpu(
    image_bytes: bytes,
    filename: str,
    *,
    gpu_step: str,
) -> Tuple[bytes, str, int, int]:
    """
    EXIF 반영 후 GPU 단계와 동일한 픽셀을 JPEG 로 전송.
    gpu_step \"generate\": FADING 정사각 중앙 크롭 + BICUBIC.
    gpu_step \"skin_edit\": SDXL 정사각 캔버스(비율 유지 + 흰 배경) + LANCZOS.
    """
    im = _pil_upright_rgb_from_bytes(image_bytes)
    mode = _image_preprocess_mode()

    if mode == "legacy_cover":
        w, h = im.size
    elif mode == "diffusers_vae":
        im, w, h = _diffusers_vae_spatial_preprocess_rgb(im)
    elif gpu_step == "generate":
        fs = _fading_preprocess_size()
        im = _preprocess_for_fading_pil(im, fs)
        w, h = fs, fs
    else:
        target = _sdxl_canvas_target()
        im = _preprocess_sdxl_square_canvas_pil(im, target)
        w, h = target, target

    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=91, optimize=True)
    base = Path(filename).stem if filename else "input"
    return buf.getvalue(), f"{base}.jpg", int(w), int(h)


def _cover_crop_resize_pil_rgba(
    im: "Image.Image",
    ref_width: int,
    ref_height: int,
    *,
    apply_extra_center_zoom: bool = False,
) -> "Image.Image":
    """
    cover 크롭 → (ref_width, ref_height) 리샘플.
    apply_extra_center_zoom=True 일 때만 원본용 추가 중앙 줌 (생성물 경로는 False).
    """
    from PIL import Image

    im = im.convert("RGBA")
    if apply_extra_center_zoom:
        im = _apply_center_zoom_square(im, _compare_center_zoom())
    w, h = im.size
    if w <= 0 or h <= 0 or ref_width <= 0 or ref_height <= 0:
        return im
    tgt_ar = ref_width / ref_height
    src_ar = w / h
    if abs(src_ar - tgt_ar) > 1e-6:
        if src_ar > tgt_ar:
            new_w = max(1, int(round(h * tgt_ar)))
            left = max(0, (w - new_w) // 2)
            im = im.crop((left, 0, left + new_w, h))
        else:
            new_h = max(1, int(round(w / tgt_ar)))
            top = max(0, (h - new_h) // 2)
            im = im.crop((0, top, w, top + new_h))
    if im.size == (ref_width, ref_height):
        return im
    return im.resize((ref_width, ref_height), Image.Resampling.LANCZOS)


def _gpu_match_map_output_to_reference_pil(
    im: "Image.Image", ref_width: int, ref_height: int
) -> "Image.Image":
    """GPU 출력을 서버가 보낸 정사각/캔버스 ref 픽셀에 맞춤."""
    from PIL import Image

    im = im.convert("RGBA")
    ow, oh = im.size
    if ow == ref_width and oh == ref_height:
        return im
    ref_ar = ref_width / ref_height
    out_ar = ow / oh if oh else ref_ar
    if abs(ref_ar - out_ar) < 0.02:
        return im.resize((ref_width, ref_height), Image.Resampling.LANCZOS).convert(
            "RGBA"
        )
    return _cover_crop_resize_pil_rgba(
        im, ref_width, ref_height, apply_extra_center_zoom=False
    )


def _gpu_output_pixels_to_reference(
    output_path: str, ref_width: int, ref_height: int
) -> Optional[Tuple[int, int]]:
    """
    생성물을 ref(W×H)에 맞춤.
    gpu_match: 정사각 캔버스/512 출력을 ref 에 Lanczos(또는 종횡비 크게 다르면 cover).
    legacy_cover / diffusers_vae: 기존 분기.
    """
    try:
        if ref_width <= 0 or ref_height <= 0:
            return None
        from PIL import Image

        with Image.open(output_path) as im:
            mode = _image_preprocess_mode()
            if mode == "legacy_cover":
                out = _cover_crop_resize_pil_rgba(
                    im, ref_width, ref_height, apply_extra_center_zoom=False
                )
            elif mode == "diffusers_vae":
                out = _diffusers_map_output_to_reference_pil(
                    im, ref_width, ref_height
                )
            else:
                out = _gpu_match_map_output_to_reference_pil(
                    im, ref_width, ref_height
                )
        out.save(output_path, format="PNG")
        return (ref_width, ref_height)
    except Exception as e:
        print(f"⚠️ 생성 이미지 ref 맞춤 실패 (건너뜀): {e}")
        return None


def _diffusers_map_output_to_reference_pil(
    im: "Image.Image", ref_width: int, ref_height: int
) -> "Image.Image":
    """diffusers 기본 리사이즈에 가깝게 맞추되, 종횡비 크게 어긋나면 cover."""
    from PIL import Image

    im = im.convert("RGBA")
    ow, oh = im.size
    if ow == ref_width and oh == ref_height:
        return im
    ref_ar = ref_width / ref_height
    out_ar = ow / oh if oh else ref_ar
    if abs(ref_ar - out_ar) < 0.015:
        return im.resize((ref_width, ref_height), Image.Resampling.LANCZOS).convert(
            "RGBA"
        )
    return _cover_crop_resize_pil_rgba(
        im, ref_width, ref_height, apply_extra_center_zoom=False
    )


def _align_local_original_file_to_ref_pixels(
    original_path_or_url: str,
    ref_width: int,
    ref_height: int,
    *,
    align_phase: Optional[str] = None,
) -> bool:
    """
    디스크 원본을 GPU 와 동일한 전처리 결과로 덮어씀.
    gpu_match + align_phase:
      generate — FADING 512(또는 IMAGE_PREPROCESS_FADING_SIZE) 직후 /generate 와 동일.
      skin_edit_direct — 원본만 skin-edit 태울 때와 동일(캔버스만).
      skin_edit_chain — /generate → /skin-edit 파이프: fading 후 SDXL 캔버스(생성물과 동일 경로).
    legacy_cover / diffusers_vae: align_phase 무시, 기존 규칙.
    URL(http) 이 아닐 때만 동작.
    """
    if (original_path_or_url or "").strip().startswith("http"):
        return False
    local = os.path.abspath(original_path_or_url.strip())
    if not os.path.isfile(local):
        return False
    try:
        from PIL import Image, ImageOps

        with open(local, "rb") as f:
            raw = f.read()
        im = Image.open(io.BytesIO(raw))
        im = ImageOps.exif_transpose(im)
        if im.mode in ("RGBA", "P"):
            bg = Image.new("RGB", im.size, (255, 255, 255))
            if im.mode == "P":
                im = im.convert("RGBA")
            bg.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
            im = bg
        elif im.mode != "RGB":
            im = im.convert("RGB")

        ext = Path(local).suffix.lower()
        mode = _image_preprocess_mode()
        if mode == "legacy_cover":
            out = _cover_crop_resize_pil_rgba(
                im, ref_width, ref_height, apply_extra_center_zoom=True
            )
            if ext in (".jpg", ".jpeg"):
                out.convert("RGB").save(local, format="JPEG", quality=93)
            else:
                out.save(local, format="PNG")
        elif mode == "diffusers_vae":
            out_rgb, rw, rh = _diffusers_vae_spatial_preprocess_rgb(im)
            if (rw, rh) != (ref_width, ref_height):
                print(
                    f"⚠️ 원본 정렬: 전처리 크기 {rw}x{rh} 가 ref {ref_width}x{ref_height} 와 다름 (ref 기준 재샘플)"
                )
                out_rgb = out_rgb.resize(
                    (ref_width, ref_height), Image.Resampling.LANCZOS
                )
            if ext in (".jpg", ".jpeg"):
                out_rgb.save(local, format="JPEG", quality=93)
            else:
                out_rgb.save(local, format="PNG")
        elif align_phase == "generate":
            out_rgb = _preprocess_for_fading_pil(im, _fading_preprocess_size())
            if ext in (".jpg", ".jpeg"):
                out_rgb.save(local, format="JPEG", quality=93)
            else:
                out_rgb.save(local, format="PNG")
        elif align_phase == "skin_edit_direct":
            out_rgb = _preprocess_sdxl_square_canvas_pil(im, _sdxl_canvas_target())
            if ext in (".jpg", ".jpeg"):
                out_rgb.save(local, format="JPEG", quality=93)
            else:
                out_rgb.save(local, format="PNG")
        elif align_phase == "skin_edit_chain":
            fs = _fading_preprocess_size()
            faded = _preprocess_for_fading_pil(im, fs)
            out_rgb = _preprocess_sdxl_square_canvas_pil(faded, _sdxl_canvas_target())
            if ext in (".jpg", ".jpeg"):
                out_rgb.save(local, format="JPEG", quality=93)
            else:
                out_rgb.save(local, format="PNG")
        else:
            print(
                f"⚠️ 원본 정렬: gpu_match 인데 align_phase 가 없음 ({align_phase!r}), 건너뜀"
            )
            return False

        phase_s = f", phase={align_phase}" if align_phase else ""
        print(
            f"✅ 원본 파일 정렬 ({mode}{phase_s}): {local} → {ref_width}x{ref_height}"
        )
        return True
    except Exception as e:
        print(f"⚠️ 원본 파일 정렬 실패 (건너뜀): {local} — {e}")
        return False


class ImageGenerationService:

    def __init__(self):
        self.gpu_client = GPUImageClient()
        self.gpu_server_url = self.gpu_client.base_url
        self.api_key = self.gpu_client.api_key
        self.enabled = self.gpu_client.enabled

    @staticmethod
    def _all_perfect_gpu_skin_scores() -> Dict[str, int]:
        """GPU /skin-edit 폼용 습관 점수 전부 최선(100)."""
        return {
            "uv_score": 100,
            "sleep_score": 100,
            "exercise_score": 100,
            "smoking_score": 100,
            "alcohol_score": 100,
            "stress_score": 100,
        }

    async def _skin_edit_chain_single_pass(
        self,
        *,
        lifestyle: Lifestyle,
        gpu_in: bytes,
        gpu_fn: str,
        tw: int,
        th: int,
        skin_scores: Dict[str, int],
        source_image_url: str,
    ) -> Tuple[str, Dict[str, Any]]:
        """동일 /generate 산출물(gpu_in)에 대해 skin-edit 1회."""
        result = await self.gpu_client.callSkinEdit(
            image_bytes=gpu_in,
            filename=gpu_fn,
            **skin_scores,
            prompt=None,
            negative_prompt=None,
            strength=GPU_SKIN_EDIT_STRENGTH,
            guidance_scale=GPU_SKIN_EDIT_GUIDANCE_SCALE,
            num_inference_steps=GPU_SKIN_EDIT_NUM_INFERENCE_STEPS,
            seed=GPU_SKIN_EDIT_SEED,
            max_side=_skin_edit_max_side(),
        )
        output_url = result["saved_path"]
        matched_px = _gpu_output_pixels_to_reference(output_url, tw, th)
        chain_align = (
            "skin_edit_chain" if _image_preprocess_mode() == "gpu_match" else None
        )
        if matched_px:
            _align_local_original_file_to_ref_pixels(
                lifestyle.original_image_url,
                tw,
                th,
                align_phase=chain_align,
            )
        trace = {
            "source_image_url": source_image_url,
            "gpu_skin_scores": skin_scores,
            "endpoint": result.get("endpoint") or "/skin-edit",
            "stable_diffusion": {
                "strength": GPU_SKIN_EDIT_STRENGTH,
                "guidance_scale": GPU_SKIN_EDIT_GUIDANCE_SCALE,
                "num_inference_steps": GPU_SKIN_EDIT_NUM_INFERENCE_STEPS,
                "seed": GPU_SKIN_EDIT_SEED,
                "max_side": _skin_edit_max_side(),
            },
            "gpu_request": result.get("gpu_request"),
            "input_image_bytes": len(gpu_in),
            "input_filename": gpu_fn,
            "output_matched_to_original_px": list(matched_px) if matched_px else None,
        }
        return output_url, trace

    async def request_aging_simulation(
        self,
        lifestyle_id: int,
        user_id: Optional[int] = None,
        db: Optional[Session] = None,
        gender: Optional[str] = None,
        target_years: Optional[int] = None,
        habits: Optional[Dict[str, Any]] = None,
    ):
        if not self.enabled:
            raise Exception("IMAGE_GENERATION_BASE_URL (or IMAGE_GENERATION_API_URL) not set")

        owns_session = db is None
        if db is None:
            db = SessionLocal()

        try:
            query = db.query(Lifestyle).filter(Lifestyle.id == lifestyle_id)
            if user_id is not None:
                query = query.filter(Lifestyle.user_id == user_id)
            lifestyle = query.first()

            if not lifestyle:
                raise Exception("Lifestyle not found")

            source_image_url = lifestyle.original_image_url
            if not source_image_url:
                raise Exception("Original image not found")
            raw_bytes, raw_name = await self._load_image_bytes(source_image_url)
            gpu_in, gpu_fn, tw, th = _upright_jpeg_bytes_for_gpu(
                raw_bytes, raw_name, gpu_step="skin_edit"
            )

            base_habits = {
                "smoking_status": lifestyle.smoking_status,
                "uv_exposure_10to16": lifestyle.uv_exposure_10to16,
                "drinking_days_per_week": lifestyle.drinking_days_per_week,
                "sleep_hours_weekday": lifestyle.sleep_hours_weekday,
                "stress_score": lifestyle.stress_score,
                "aerobic_weekly": lifestyle.aerobic_weekly,
                "resistance_weekly": lifestyle.resistance_weekly,
                "sunscreen_frequency": lifestyle.sunscreen_frequency,
            }
            if habits:
                base_habits.update({k: v for k, v in habits.items() if v is not None})

            effective_habits = dict(base_habits)

            effective_gender = gender or (lifestyle.owner.gender if lifestyle.owner else None)
            effective_target_years = target_years if target_years is not None else 30  # 응답용 (이미지 생성은 callGenerate에서 3 사용)

            aging_score = self._calculate_score(effective_habits)
            current_age = self._extract_current_age(lifestyle)
            skin_scores = self._map_habits_to_gpu_skin_scores(base_habits)

            result = await self.gpu_client.callSkinEdit(
                image_bytes=gpu_in,
                filename=gpu_fn,
                **skin_scores,
                prompt=None,
                negative_prompt=None,
                strength=GPU_SKIN_EDIT_STRENGTH,
                guidance_scale=GPU_SKIN_EDIT_GUIDANCE_SCALE,
                num_inference_steps=GPU_SKIN_EDIT_NUM_INFERENCE_STEPS,
                seed=GPU_SKIN_EDIT_SEED,
                max_side=_skin_edit_max_side(),
            )
            output_url = result["saved_path"]
            matched_px = _gpu_output_pixels_to_reference(output_url, tw, th)
            if matched_px:
                _align_local_original_file_to_ref_pixels(
                    lifestyle.original_image_url,
                    tw,
                    th,
                    align_phase="skin_edit_direct"
                    if _image_preprocess_mode() == "gpu_match"
                    else None,
                )

            lifestyle.generated_image_url = output_url
            db.commit()

            return {
                "output_url": output_url,
                "image_url": output_url,
                "status": "completed",
                "params": {
                    "aging_strength": aging_score,
                    "gender": effective_gender,
                    "target_years": effective_target_years,
                    "current_age": current_age,
                    "habits": effective_habits,
                    "endpoint": result.get("endpoint") or "/skin-edit",
                    "gpu_skin_scores": skin_scores,
                    "stable_diffusion": {
                        "strength": GPU_SKIN_EDIT_STRENGTH,
                        "guidance_scale": GPU_SKIN_EDIT_GUIDANCE_SCALE,
                        "num_inference_steps": GPU_SKIN_EDIT_NUM_INFERENCE_STEPS,
                        "seed": GPU_SKIN_EDIT_SEED,
                        "max_side": _skin_edit_max_side(),
                    },
                    "gpu_request": result.get("gpu_request"),
                    "input_image_bytes": len(gpu_in),
                    "input_filename": gpu_fn,
                    "output_matched_to_original_px": list(matched_px)
                    if matched_px
                    else None,
                },
            }
        except httpx.ConnectError as e:
            host = urlparse(self.gpu_server_url).hostname if self.gpu_server_url else None
            raise Exception(
                f"이미지 생성 서버 연결 실패 (host={host}, url={self.gpu_server_url}): {e}"
            ) from e
        except httpx.RequestError as e:
            host = urlparse(self.gpu_server_url).hostname if self.gpu_server_url else None
            raise Exception(
                f"이미지 생성 요청 실패 (host={host}, url={self.gpu_server_url}): {e}"
            ) from e
        finally:
            if owns_session and db is not None:
                db.close()

    async def request_generate_image(
        self,
        lifestyle_id: int,
        user_id: Optional[int] = None,
        db: Optional[Session] = None,
        target_years: int = 13,  # 미래 얼굴 이미지 생성에 넘기는 값 (고정 13)
        current_age: Optional[int] = None,
        gender: Optional[str] = None,
        seed_base: int = 1000,
    ) -> Dict[str, Any]:
        if not self.enabled:
            raise Exception("IMAGE_GENERATION_BASE_URL (or IMAGE_GENERATION_API_URL) not set")

        owns_session = db is None
        if db is None:
            db = SessionLocal()

        try:
            query = db.query(Lifestyle).filter(Lifestyle.id == lifestyle_id)
            if user_id is not None:
                query = query.filter(Lifestyle.user_id == user_id)
            lifestyle = query.first()
            if not lifestyle:
                raise Exception("Lifestyle not found")
            if not lifestyle.original_image_url:
                raise Exception("Original image not found")

            raw_bytes, raw_name = await self._load_image_bytes(lifestyle.original_image_url)
            gpu_in, gpu_fn, tw, th = _upright_jpeg_bytes_for_gpu(
                raw_bytes, raw_name, gpu_step="generate"
            )
            effective_gender = gender or (lifestyle.owner.gender if lifestyle.owner else None)
            effective_age = (
                current_age
                if current_age is not None
                else self._extract_current_age(lifestyle)
            )
            gpu_age = effective_age if effective_age is not None else -1

            result = await self.gpu_client.callGenerate(
                image_bytes=gpu_in,
                filename=gpu_fn,
                target_years=target_years,
                current_age=gpu_age,
                gender=GPUImageClient.normalize_gpu_gender(effective_gender),
                seed_base=seed_base,
            )
            output_url = result["saved_path"]
            matched_px = _gpu_output_pixels_to_reference(output_url, tw, th)
            if matched_px:
                _align_local_original_file_to_ref_pixels(
                    lifestyle.original_image_url,
                    tw,
                    th,
                    align_phase="generate"
                    if _image_preprocess_mode() == "gpu_match"
                    else None,
                )
            lifestyle.generated_image_url = output_url
            db.commit()

            return {
                "output_url": output_url,
                "image_url": output_url,
                "status": "completed",
                "params": {
                    "endpoint": result.get("endpoint") or "/generate",
                    "target_years": target_years,
                    "current_age": effective_age,
                    "gender": effective_gender,
                    "seed_base": seed_base,
                    "gpu_request": result.get("gpu_request"),
                    "input_image_bytes": len(gpu_in),
                    "input_filename": gpu_fn,
                    "output_matched_to_original_px": list(matched_px)
                    if matched_px
                    else None,
                },
            }
        finally:
            if owns_session and db is not None:
                db.close()

    async def request_skin_edit_from_generated(
        self,
        lifestyle_id: int,
        user_id: Optional[int] = None,
        db: Optional[Session] = None,
    ) -> Dict[str, Any]:
        """최근 /generate 결과 이미지를 입력으로 GPU /skin-edit 호출(폼 필드는 GPU 스펙만)."""
        if not self.enabled:
            raise Exception("IMAGE_GENERATION_BASE_URL (or IMAGE_GENERATION_API_URL) not set")

        owns_session = db is None
        if db is None:
            db = SessionLocal()

        try:
            query = db.query(Lifestyle).filter(Lifestyle.id == lifestyle_id)
            if user_id is not None:
                query = query.filter(Lifestyle.user_id == user_id)
            lifestyle = query.first()
            if not lifestyle:
                raise Exception("Lifestyle not found")

            source_image_url = (
                (lifestyle.generated_image_url or "").strip()
                or (lifestyle.original_image_url or "").strip()
            )
            if not source_image_url:
                raise Exception("Generated image not found")

            if _image_preprocess_mode() == "gpu_match":
                ct = _sdxl_canvas_target()
                tw, th = ct, ct
            else:
                orig_ref_bytes, orig_ref_name = await self._load_image_bytes(
                    lifestyle.original_image_url
                )
                _, _, tw, th = _upright_jpeg_bytes_for_gpu(
                    orig_ref_bytes, orig_ref_name, gpu_step="generate"
                )
            raw_sb, raw_sf = await self._load_image_bytes(source_image_url)
            gpu_in, gpu_fn, _, _ = _upright_jpeg_bytes_for_gpu(
                raw_sb, raw_sf, gpu_step="skin_edit"
            )
            base_habits = {
                "smoking_status": lifestyle.smoking_status,
                "uv_exposure_10to16": lifestyle.uv_exposure_10to16,
                "drinking_days_per_week": lifestyle.drinking_days_per_week,
                "sleep_hours_weekday": lifestyle.sleep_hours_weekday,
                "stress_score": lifestyle.stress_score,
                "aerobic_weekly": lifestyle.aerobic_weekly,
                "resistance_weekly": lifestyle.resistance_weekly,
                "sunscreen_frequency": lifestyle.sunscreen_frequency,
            }
            skin_scores = self._map_habits_to_gpu_skin_scores(base_habits)

            # 1) 설문 습관 → 리포트/결과 화면·미래얼굴 오른쪽에 쓰는 URL
            survey_url, survey_trace = await self._skin_edit_chain_single_pass(
                lifestyle=lifestyle,
                gpu_in=gpu_in,
                gpu_fn=gpu_fn,
                tw=tw,
                th=th,
                skin_scores=skin_scores,
                source_image_url=source_image_url,
            )
            lifestyle.generated_image_url = survey_url

            # 2) 동일 gpu_in + 점수 전부 100 → 미래 얼굴 탭 슬라이더 왼쪽만 (리포트에서는 사용 안 함)
            ideal_url: Optional[str] = None
            ideal_trace: Optional[Dict[str, Any]] = None
            try:
                perfect = self._all_perfect_gpu_skin_scores()
                ideal_url, ideal_trace = await self._skin_edit_chain_single_pass(
                    lifestyle=lifestyle,
                    gpu_in=gpu_in,
                    gpu_fn=gpu_fn,
                    tw=tw,
                    th=th,
                    skin_scores=perfect,
                    source_image_url=source_image_url,
                )
                lifestyle.ideal_habits_skin_image_url = ideal_url
            except Exception as e:
                print(
                    f"⚠️ 습관 만점 skin-edit 실패(미래얼굴 왼쪽 이미지 생략): lifestyle_id={lifestyle_id} — {e}"
                )
                lifestyle.ideal_habits_skin_image_url = None

            db.commit()

            return {
                "output_url": survey_url,
                "image_url": survey_url,
                "ideal_habits_image_url": ideal_url,
                "status": "completed",
                "params": {
                    "survey_skin_edit": survey_trace,
                    "ideal_habits_skin_edit": ideal_trace,
                },
            }
        finally:
            if owns_session and db is not None:
                db.close()

    async def check_gpu_health(self) -> Dict[str, Any]:
        return await self.gpu_client.check_health()

    async def _load_image_bytes(self, path_or_url: str) -> Tuple[bytes, str]:
        value = (path_or_url or "").strip()
        if not value:
            raise Exception("원본 이미지 경로가 비어 있습니다.")

        if value.startswith("http://") or value.startswith("https://"):
            async with httpx.AsyncClient(timeout=30) as client:
                response = await client.get(value)
            if response.status_code >= 400:
                raise Exception(
                    f"원본 이미지 다운로드 실패(status={response.status_code}): {value}"
                )
            filename = Path(urlparse(value).path).name or "input.png"
            return response.content, filename

        local_path = os.path.abspath(value)
        if not os.path.exists(local_path) or not os.path.isfile(local_path):
            raise Exception(f"원본 이미지 파일을 찾을 수 없습니다: {local_path}")
        with open(local_path, "rb") as f:
            image_bytes = f.read()
        return image_bytes, Path(local_path).name

    @staticmethod
    def _extract_current_age(lifestyle: Lifestyle) -> Optional[int]:
        owner = lifestyle.owner
        if owner is None or owner.birthdate is None:
            return None
        today = date.today()
        birth = owner.birthdate
        return today.year - birth.year - ((today.month, today.day) < (birth.month, birth.day))

    def _calculate_score(self, habits: Dict[str, Any]) -> float:
        score = 0.2

        if habits.get("smoking_status") == "current":
            score += 0.25

        uv_exposure = habits.get("uv_exposure_10to16")
        if uv_exposure in ["1~2h", ">2h"]:
            score += 0.2

        sleep_hours = habits.get("sleep_hours_weekday")
        try:
            if sleep_hours is not None and float(sleep_hours) < 6:
                score += 0.15
        except (TypeError, ValueError):
            pass

        stress_score = habits.get("stress_score")
        try:
            if stress_score is not None and float(stress_score) >= 7:
                score += 0.1
        except (TypeError, ValueError):
            pass

        drinking = habits.get("drinking_days_per_week")
        if drinking in ["4-5", "6-7", "4~5", "6~7"]:
            score += 0.1

        return min(max(score, 0.0), 1.0)

    @classmethod
    def _map_habits_to_gpu_skin_scores(cls, habits: Dict[str, Any]) -> Dict[str, int]:
        """
        GPU /skin-edit Form용 점수. 모두 동일 규칙: 나쁜 조건이면 0, 그 외 100.

        - smoking: current → 0
        - uv: 매일(재도포) 선크림 또는 야외 <30m → 100, 둘 다 해당 없으면 0 (미응답 둘 다면 100)
        - sleep: 평일 수면 < 7.5h → 0
        - alcohol: 주 6–7일 → 0
        - stress: 0–10 척도에서 ≥ 7 → 0
        - exercise: 유산소 0/1–2/3–4 이거나 근력 0/1회 → 0; 둘 다 미응답이면 100

        (/generate 는 점수 필드를 받지 않음.)
        """
        smoking = (habits.get("smoking_status") or "").strip().lower()
        smoking_score = 0 if smoking == "current" else 100

        uv_raw = str(habits.get("uv_exposure_10to16") or "").strip()
        sf = str(habits.get("sunscreen_frequency") or "").strip().lower()
        daily_sunscreen = sf in ("daily_with_reapply", "6-7")
        minimal_outdoor = uv_raw == "<30m"
        if daily_sunscreen or minimal_outdoor:
            uv_score = 100
        elif not uv_raw and not sf:
            uv_score = 100
        else:
            uv_score = 0

        sleep_hours = habits.get("sleep_hours_weekday")
        try:
            sh = float(sleep_hours) if sleep_hours is not None else None
        except (TypeError, ValueError):
            sh = None
        if sh is None:
            sleep_score = 100
        else:
            sleep_score = 0 if sh < 7.5 else 100

        drink = str(habits.get("drinking_days_per_week") or "").strip()
        alcohol_score = 0 if drink in ("6-7", "6~7") else 100

        stress_raw = habits.get("stress_score")
        try:
            st = float(stress_raw) if stress_raw is not None else None
        except (TypeError, ValueError):
            st = None
        if st is None:
            stress_score = 100
        else:
            stress_score = 0 if st >= 7.0 else 100

        aerobic = str(habits.get("aerobic_weekly") or "").strip()
        resistance = str(habits.get("resistance_weekly") or "").strip()
        aerobic_bad = aerobic in ("0", "1-2", "3-4")
        resistance_bad = resistance in ("0", "1")
        if not aerobic and not resistance:
            exercise_score = 100
        else:
            exercise_score = 0 if (aerobic_bad or resistance_bad) else 100

        return {
            "uv_score": uv_score,
            "sleep_score": sleep_score,
            "exercise_score": exercise_score,
            "smoking_score": smoking_score,
            "alcohol_score": alcohol_score,
            "stress_score": stress_score,
        }


image_service = ImageGenerationService()
image_gen_service = image_service
