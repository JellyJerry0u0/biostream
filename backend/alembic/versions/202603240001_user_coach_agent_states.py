"""user coach agent persisted state (JSON)

Revision ID: 202603240001
Revises: 202603220003
Create Date: 2026-03-24

"""
from alembic import op
import sqlalchemy as sa

revision = "202603240001"
down_revision = "202603220003"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "user_coach_agent_states",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("state", sa.JSON(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )


def downgrade():
    op.drop_table("user_coach_agent_states")
