"""add user smoking_status

Revision ID: 202603200003
Revises: 202603200002
Create Date: 2026-03-20

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '202603200003'
down_revision = '202603200002'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('users', sa.Column('smoking_status', sa.String(), nullable=True))


def downgrade():
    op.drop_column('users', 'smoking_status')
