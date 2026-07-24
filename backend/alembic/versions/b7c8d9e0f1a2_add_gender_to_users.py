"""add gender to users

Revision ID: b7c8d9e0f1a2
Revises: a1b2c3d4e5f6
Create Date: 2026-07-19 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'b7c8d9e0f1a2'
down_revision: Union[str, None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nullable — gender is optional on the signup form, so no backfill needed.
    op.add_column('users', sa.Column('gender', sa.String(length=30), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'gender')
