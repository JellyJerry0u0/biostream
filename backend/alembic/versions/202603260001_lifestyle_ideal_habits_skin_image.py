"""lifestyles.ideal_habits_skin_image_url — generate 동일 입력, 습관 만점 skin-edit

Revision ID: 202603260001
Revises: 202603240001
Create Date: 2026-03-26

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "202603260001"
down_revision: Union[str, None] = "202603240001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "lifestyles",
        sa.Column("ideal_habits_skin_image_url", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("lifestyles", "ideal_habits_skin_image_url")
