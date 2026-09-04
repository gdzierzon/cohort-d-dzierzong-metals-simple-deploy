from unittest.mock import MagicMock

import pytest


@pytest.fixture
def mocked_session_factory():
    session = MagicMock(name="database_session")
    context_manager = MagicMock(name="session_context")
    context_manager.__enter__.return_value = session
    context_manager.__exit__.return_value = False
    session_factory = MagicMock(
        name="SessionFactory",
        return_value=context_manager,
    )
    return session, session_factory, context_manager
