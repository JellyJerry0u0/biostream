"""health_reports 테이블 생성 (health_report DB 분리)

Revision ID: 202603200001
Revises: 202603190001
Create Date: 2026-03-20 00:01:00

health_report를 lifestyles에서 분리하여 health_reports 테이블로 이동합니다.
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "202603200001"
down_revision = "202603190001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. health_reports 테이블 생성
    op.create_table(
        "health_reports",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column(
            "lifestyle_id",
            sa.Integer(),
            sa.ForeignKey("lifestyles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("report", sa.JSON(), nullable=False),
        sa.Column("generated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_health_reports_id", "health_reports", ["id"])
    op.create_index("ix_health_reports_lifestyle_id", "health_reports", ["lifestyle_id"], unique=True)

    # 2. 기존 lifestyles 데이터를 health_reports로 이전
    op.execute("""
        INSERT INTO health_reports (lifestyle_id, report, generated_at)
        SELECT id, health_report, COALESCE(health_report_generated_at, NOW())
        FROM lifestyles
        WHERE health_report IS NOT NULL
    """)

    # 3. lifestyles에서 health_report, health_report_generated_at 컬럼 제거
    op.drop_column("lifestyles", "health_report")
    op.drop_column("lifestyles", "health_report_generated_at")


def downgrade() -> None:
    # 1. lifestyles에 컬럼 복원
    op.add_column(
        "lifestyles",
        sa.Column("health_report", sa.JSON(), nullable=True),
    )
    op.add_column(
        "lifestyles",
        sa.Column("health_report_generated_at", sa.DateTime(timezone=True), nullable=True),
    )

    # 2. health_reports 데이터를 lifestyles로 복원
    op.execute("""
        UPDATE lifestyles l
        SET
            health_report = r.report,
            health_report_generated_at = r.generated_at
        FROM health_reports r
        WHERE l.id = r.lifestyle_id
    """)

    # 3. health_reports 테이블 삭제
    op.drop_index("ix_health_reports_lifestyle_id", table_name="health_reports")
    op.drop_index("ix_health_reports_id", table_name="health_reports")
    op.drop_table("health_reports")
