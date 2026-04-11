"""add uv prompt fields to health_data

Revision ID: 202603190001
Revises: 202603170001
Create Date: 2026-03-19 00:01:00
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "202603190001"
down_revision = "202603170001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "health_data",
        sa.Column("outdoor_prompt_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "health_data",
        sa.Column("outdoor_yes_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "health_data",
        sa.Column("outdoor_no_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "health_data",
        sa.Column("outdoor_unknown_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "health_data",
        sa.Column("uv_exposure_score", sa.Float(), nullable=False, server_default="0"),
    )
    op.add_column(
        "health_data",
        sa.Column(
            "uv_source",
            sa.String(),
            nullable=False,
            server_default="self_reported_step_prompt",
        ),
    )


def downgrade() -> None:
    op.drop_column("health_data", "uv_source")
    op.drop_column("health_data", "uv_exposure_score")
    op.drop_column("health_data", "outdoor_unknown_count")
    op.drop_column("health_data", "outdoor_no_count")
    op.drop_column("health_data", "outdoor_yes_count")
    op.drop_column("health_data", "outdoor_prompt_count")
