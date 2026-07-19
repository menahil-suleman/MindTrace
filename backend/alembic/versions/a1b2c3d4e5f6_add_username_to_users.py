"""add username to users

Revision ID: a1b2c3d4e5f6
Revises: 388eb01e7055
Create Date: 2026-07-18 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, None] = '388eb01e7055'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add username column — nullable first so existing rows don't violate the constraint,
    # then backfill with a placeholder derived from the row id, then set NOT NULL.
    op.add_column('users', sa.Column('username', sa.String(length=50), nullable=True))
    op.execute("UPDATE users SET username = 'user_' || SUBSTRING(id, 1, 8) WHERE username IS NULL")
    op.alter_column('users', 'username', nullable=False)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_column('users', 'username')
