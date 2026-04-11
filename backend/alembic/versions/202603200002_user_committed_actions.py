"""user_committed_actions, action_check_ins 테이블 생성

Revision ID: 202603200002
Revises: 202603200001
Create Date: 2026-03-20 00:02:00

사용자가 선택한 습관 및 일별 실천 기록
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "202603200002"
down_revision = "202603200001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_committed_actions",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("lifestyle_id", sa.Integer(), sa.ForeignKey("lifestyles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("section_key", sa.String(), nullable=False),
        sa.Column("action_title", sa.String(), nullable=False),
        sa.Column("action_detail", sa.Text(), nullable=True),
        sa.Column("committed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("status", sa.String(), nullable=False, server_default="active"),
    )
    op.create_index("ix_user_committed_actions_id", "user_committed_actions", ["id"])
    op.create_index("ix_user_committed_actions_user_id", "user_committed_actions", ["user_id"])
    op.create_index("ix_user_committed_actions_lifestyle_id", "user_committed_actions", ["lifestyle_id"])

    op.create_table(
        "action_check_ins",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column(
            "committed_action_id",
            sa.Integer(),
            sa.ForeignKey("user_committed_actions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("check_date", sa.Date(), nullable=False),
        sa.Column("completed", sa.Boolean(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
    )
    op.create_index("ix_action_check_ins_id", "action_check_ins", ["id"])
    op.create_index("ix_action_check_ins_committed_action_id", "action_check_ins", ["committed_action_id"])
    op.create_index("ix_action_check_ins_check_date", "action_check_ins", ["check_date"])
    op.create_unique_constraint(
        "uq_action_check_ins_action_date",
        "action_check_ins",
        ["committed_action_id", "check_date"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_action_check_ins_action_date", "action_check_ins", type_="unique")
    op.drop_index("ix_action_check_ins_check_date", table_name="action_check_ins")
    op.drop_index("ix_action_check_ins_committed_action_id", table_name="action_check_ins")
    op.drop_index("ix_action_check_ins_id", table_name="action_check_ins")
    op.drop_table("action_check_ins")

    op.drop_index("ix_user_committed_actions_lifestyle_id", table_name="user_committed_actions")
    op.drop_index("ix_user_committed_actions_user_id", table_name="user_committed_actions")
    op.drop_index("ix_user_committed_actions_id", table_name="user_committed_actions")
    op.drop_table("user_committed_actions")
