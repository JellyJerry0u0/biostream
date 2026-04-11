"""remove caffeine and skin_concerns from lifestyles

Revision ID: 202603220001
Revises: 202603200003
Create Date: 2026-03-22

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '202603220001'
down_revision = '202603200003'
branch_labels = None
depends_on = None


def upgrade():
    op.drop_column('lifestyles', 'caffeine_intake')
    op.drop_column('lifestyles', 'caffeine_timing')
    op.drop_column('lifestyles', 'skin_concerns')


def downgrade():
    op.add_column('lifestyles', sa.Column('caffeine_intake', sa.String(), nullable=True))
    op.add_column('lifestyles', sa.Column('caffeine_timing', sa.String(), nullable=True))
    op.add_column('lifestyles', sa.Column('skin_concerns', sa.JSON(), nullable=True))
