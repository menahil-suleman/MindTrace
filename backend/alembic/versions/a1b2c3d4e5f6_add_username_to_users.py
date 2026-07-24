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
    # substr() (not SUBSTRING()) works on both Postgres and SQLite, so this
    # backfill runs the same way whichever database is behind DATABASE_URL.
    op.execute("UPDATE users SET username = 'user_' || substr(id, 1, 8) WHERE username IS NULL")
    # batch_alter_table is required for SQLite, which can't ALTER COLUMN directly —
    # it transparently recreates the table there. On Postgres it just runs a normal
    # ALTER TABLE, so this is safe either way.
    with op.batch_alter_table('users') as batch_op:
        batch_op.alter_column('username', nullable=False)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_column('users', 'username')
