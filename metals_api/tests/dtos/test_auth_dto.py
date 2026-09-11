import unicodedata

import pytest

from dtos.auth_dto import (
    PASSWORD_MAXIMUM_LENGTH,
    PASSWORD_MINIMUM_LENGTH,
    LoginDTO,
    RegisterDTO,
    normalize_password,
)


SENTENCE = "my grandmother collected silver coins"


def _register(username="new_student", password=SENTENCE):
    return {"username": username, "password": password}


class TestPasswordPolicy:
    def test_a_sentence_with_spaces_is_accepted(self):
        assert RegisterDTO.validate(_register()) == []

    def test_no_character_classes_are_required(self):
        # All lowercase, no digits, no symbols - long is the only requirement.
        assert RegisterDTO.validate(_register(password="correct horse battery")) == []

    def test_exactly_the_minimum_is_accepted(self):
        password = "a" + "bcdefghij klmno"[: PASSWORD_MINIMUM_LENGTH - 1]
        assert len(password) == PASSWORD_MINIMUM_LENGTH
        assert RegisterDTO.validate(_register(password=password)) == []

    def test_one_character_short_is_rejected_with_a_helpful_hint(self):
        errors = RegisterDTO.validate(_register(password="a" * (PASSWORD_MINIMUM_LENGTH - 1)))
        assert len(errors) == 1
        assert str(PASSWORD_MINIMUM_LENGTH) in errors[0]
        assert "spaces are allowed" in errors[0]

    def test_over_the_maximum_is_rejected(self):
        errors = RegisterDTO.validate(_register(password="x" + "y" * PASSWORD_MAXIMUM_LENGTH))
        assert errors == [f"password must be {PASSWORD_MAXIMUM_LENGTH} characters or fewer."]

    def test_a_single_repeated_character_is_rejected_even_when_long_enough(self):
        errors = RegisterDTO.validate(_register(password="a" * 40))
        assert errors == ["password must not be a single character repeated."]

    def test_password_containing_the_username_is_rejected(self):
        errors = RegisterDTO.validate(
            _register(username="collector", password="i am a Collector of coins")
        )
        assert errors == ["password must not contain your username."]

    def test_leading_and_trailing_spaces_are_preserved_not_trimmed(self):
        # Trimming would change the secret, and login does not trim either.
        password = f"  {SENTENCE}  "
        dto = RegisterDTO.from_dictionary(_register(password=password))
        assert dto.password == password


class TestUnicodeNormalization:
    def test_equivalent_forms_normalize_to_the_same_secret(self):
        composed = "café au lait every morning"
        decomposed = unicodedata.normalize("NFD", composed)
        assert composed != decomposed
        assert normalize_password(decomposed) == normalize_password(composed)

    def test_login_and_register_normalize_identically(self):
        decomposed = unicodedata.normalize("NFD", "café au lait every morning")
        data = {"username": "drinker", "password": decomposed}
        assert RegisterDTO.from_dictionary(data).password == LoginDTO.from_dictionary(data).password


class TestLoginIsNotLengthChecked:
    def test_short_existing_passwords_can_still_log_in(self):
        # The seeded demo accounts use "password"; the stored hash is the only
        # authority at login, so the policy must not lock them out.
        assert LoginDTO.validate({"username": "admin", "password": "password"}) == []

    def test_password_is_still_required(self):
        assert LoginDTO.validate({"username": "admin", "password": ""}) == ["password is required."]


class TestUsernamePolicy:
    @pytest.mark.parametrize("username", ["abc", "new_student", "first.last", "a-b", "user99"])
    def test_accepted_usernames(self, username):
        assert RegisterDTO.validate(_register(username=username)) == []

    @pytest.mark.parametrize(
        "username",
        [
            "ab",              # shorter than the minimum
            "has space",       # spaces are deliberately not allowed
            "_leading",        # must start alphanumeric
            "trailing-",       # must end alphanumeric
            "double__dash",    # no two separators in a row
            "dots..here",
            "café",            # ASCII only, so every name is typeable in the form
        ],
    )
    def test_rejected_usernames(self, username):
        assert RegisterDTO.validate(_register(username=username)) != []


class TestRequestShape:
    def test_non_dictionary_body_is_rejected(self):
        assert RegisterDTO.validate("not a dict") == ["A JSON request body is required."]

    def test_missing_fields_are_reported_before_policy_checks(self):
        errors = RegisterDTO.validate({})
        assert errors == ["username is required.", "password is required."]
