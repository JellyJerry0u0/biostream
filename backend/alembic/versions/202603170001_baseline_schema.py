"""baseline schema

Revision ID: 202603170001
Revises: 
Create Date: 2026-03-17 00:01:00
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "202603170001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("email", sa.String(), nullable=False),
        sa.Column("hashed_password", sa.String(), nullable=True),
        sa.Column("kakao_id", sa.String(), nullable=True),
        sa.Column("nickname", sa.String(), nullable=False),
        sa.Column("birthdate", sa.Date(), nullable=True),
        sa.Column("gender", sa.String(), nullable=True),
        sa.Column("is_pregnant", sa.Boolean(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_users_id", "users", ["id"])
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_kakao_id", "users", ["kakao_id"], unique=True)

    op.create_table(
        "user_profiles",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("profile_image_url", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_user_profiles_id", "user_profiles", ["id"])
    op.create_unique_constraint("uq_user_profiles_user_id", "user_profiles", ["user_id"])

    op.create_table(
        "lifestyles",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("original_image_url", sa.String(), nullable=True),
        sa.Column("generated_image_url", sa.String(), nullable=True),
        sa.Column("generation_status", sa.String(), nullable=True),
        sa.Column("image_gen_params", sa.JSON(), nullable=True),
        sa.Column("outcomes", sa.JSON(), nullable=True),
        sa.Column("sleep_hours_weekday", sa.Float(), nullable=True),
        sa.Column("sleep_hours_weekend", sa.Float(), nullable=True),
        sa.Column("sleep_quality_score", sa.Float(), nullable=True),
        sa.Column("uv_exposure_10to16", sa.String(), nullable=True),
        sa.Column("sunscreen_frequency", sa.String(), nullable=True),
        sa.Column("sunscreen_reapply", sa.String(), nullable=True),
        sa.Column("outdoor_sports_uv", sa.String(), nullable=True),
        sa.Column("drinking_days_per_week", sa.String(), nullable=True),
        sa.Column("drinking_amount_per_session", sa.String(), nullable=True),
        sa.Column("smoking_status", sa.String(), nullable=True),
        sa.Column("smoking_amount_per_day", sa.String(), nullable=True),
        sa.Column("stress_score", sa.Float(), nullable=True),
        sa.Column("caffeine_intake", sa.String(), nullable=True),
        sa.Column("caffeine_timing", sa.String(), nullable=True),
        sa.Column("aerobic_weekly", sa.String(), nullable=True),
        sa.Column("resistance_weekly", sa.String(), nullable=True),
        sa.Column("height", sa.Float(), nullable=True),
        sa.Column("weight", sa.Float(), nullable=True),
        sa.Column("skin_type", sa.String(), nullable=True),
        sa.Column("skin_concerns", sa.JSON(), nullable=True),
        sa.Column("skin_satisfaction", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("target_years", sa.Integer(), nullable=True),
        sa.Column("health_report", sa.JSON(), nullable=True),
        sa.Column("health_report_generated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notion_page_id", sa.String(), nullable=True),
        sa.Column("notion_url", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_lifestyles_id", "lifestyles", ["id"])

    op.create_table(
        "health_data",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("steps", sa.Integer(), nullable=False),
        sa.Column("sleep_minutes", sa.Integer(), nullable=False),
        sa.Column("distance_meters", sa.Float(), nullable=False),
        sa.Column("oxygen_saturation", sa.Float(), nullable=False),
        sa.Column("average_speed_mps", sa.Float(), nullable=False),
        sa.Column("nutrition_calories_kcal", sa.Float(), nullable=False),
        sa.Column("exercise_minutes", sa.Integer(), nullable=False),
        sa.Column("fitness_score", sa.Float(), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("height_cm", sa.Float(), nullable=False),
        sa.Column("body_fat_percentage", sa.Float(), nullable=False),
        sa.Column("vo2_max", sa.Float(), nullable=False),
        sa.Column("blood_glucose_mg_dl", sa.Float(), nullable=False),
        sa.Column("sync_date", sa.Date(), nullable=False),
        sa.Column("is_processed", sa.Boolean(), nullable=False),
        sa.Column("notification_sent", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_health_data_id", "health_data", ["id"])
    op.create_index("ix_health_data_user_id", "health_data", ["user_id"])
    op.create_index("ix_health_data_sync_date", "health_data", ["sync_date"])
    op.create_index("ix_health_data_is_processed", "health_data", ["is_processed"])
    op.create_index("ix_health_data_notification_sent", "health_data", ["notification_sent"])
    op.create_unique_constraint("uq_health_data_user_sync_date", "health_data", ["user_id", "sync_date"])

    op.create_table(
        "user_device_tokens",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_token", sa.String(), nullable=False),
        sa.Column("platform", sa.String(), nullable=False, server_default=sa.text("'android'")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
    )
    op.create_index("ix_user_device_tokens_id", "user_device_tokens", ["id"])
    op.create_index("ix_user_device_tokens_user_id", "user_device_tokens", ["user_id"])
    op.create_index("ix_user_device_tokens_device_token", "user_device_tokens", ["device_token"])
    op.create_unique_constraint("uq_user_device_tokens_user_token", "user_device_tokens", ["user_id", "device_token"])


def downgrade() -> None:
    op.drop_constraint("uq_user_device_tokens_user_token", "user_device_tokens", type_="unique")
    op.drop_index("ix_user_device_tokens_device_token", table_name="user_device_tokens")
    op.drop_index("ix_user_device_tokens_user_id", table_name="user_device_tokens")
    op.drop_index("ix_user_device_tokens_id", table_name="user_device_tokens")
    op.drop_table("user_device_tokens")

    op.drop_constraint("uq_health_data_user_sync_date", "health_data", type_="unique")
    op.drop_index("ix_health_data_notification_sent", table_name="health_data")
    op.drop_index("ix_health_data_is_processed", table_name="health_data")
    op.drop_index("ix_health_data_sync_date", table_name="health_data")
    op.drop_index("ix_health_data_user_id", table_name="health_data")
    op.drop_index("ix_health_data_id", table_name="health_data")
    op.drop_table("health_data")

    op.drop_index("ix_lifestyles_id", table_name="lifestyles")
    op.drop_table("lifestyles")

    op.drop_constraint("uq_user_profiles_user_id", "user_profiles", type_="unique")
    op.drop_index("ix_user_profiles_id", table_name="user_profiles")
    op.drop_table("user_profiles")

    op.drop_index("ix_users_kakao_id", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_index("ix_users_id", table_name="users")
    op.drop_table("users")
