import re
import unicodedata
from dataclasses import dataclass


# Password policy, deliberately based on length rather than character classes.
# NIST SP 800-63B dropped composition rules in favour of longer memorized
# secrets, and Argon2id hashes the whole input (unlike bcrypt, which silently
# truncates at 72 bytes), so a long passphrase is genuinely stronger here.
# Spaces and punctuation are allowed on purpose: a sentence is the goal.
# Mirrored in metals_ui/js/views/register-view.js - change both together.
PASSWORD_MINIMUM_LENGTH = 15
# Only a denial-of-service guard. Argon2's cost scales with input length, so the
# field cannot be unbounded.
PASSWORD_MAXIMUM_LENGTH = 128

USERNAME_MINIMUM_LENGTH = 3
USERNAME_MAXIMUM_LENGTH = 100
# ASCII only, and must begin and end with a letter or digit. Kept deliberately
# narrower than the password rules: no spaces, so there is no ambiguity about
# trimming, and no Unicode, so every username is typeable in the login form.
USERNAME_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9]")
CONSECUTIVE_SEPARATORS = re.compile(r"[._-]{2}")


def normalize_password(password: str) -> str:
    """Apply NFKC so the same phrase typed on another keyboard still matches.

    Applied identically when registering and when logging in; if the two ever
    disagreed, anyone using non-ASCII characters would be locked out.
    """
    return unicodedata.normalize("NFKC", password)


@dataclass
class LoginDTO:
    username: str
    password: str

    @classmethod
    def validate(cls, data: object) -> list[str]:
        if not isinstance(data, dict):
            return ["A JSON request body is required."]

        errors = []
        if not isinstance(data.get("username"), str) or not data["username"].strip():
            errors.append("username is required.")
        # Length is deliberately not checked when logging in. Accounts created
        # before this policy, including the seeded demo accounts, must still be
        # able to authenticate; the stored hash is the only authority.
        if not isinstance(data.get("password"), str) or not data["password"]:
            errors.append("password is required.")
        return errors

    @classmethod
    def from_dictionary(cls, data: dict) -> "LoginDTO":
        return cls(
            username=data["username"],
            password=normalize_password(data["password"]),
        )


@dataclass
class RegisterDTO(LoginDTO):
    @classmethod
    def validate(cls, data: object) -> list[str]:
        errors = super().validate(data)
        if errors or not isinstance(data, dict):
            return errors

        username = data["username"].strip()
        errors.extend(cls._username_errors(username))
        errors.extend(cls._password_errors(normalize_password(data["password"]), username))
        return errors

    @classmethod
    def _username_errors(cls, username: str) -> list[str]:
        if not USERNAME_MINIMUM_LENGTH <= len(username) <= USERNAME_MAXIMUM_LENGTH:
            return [
                f"username must be between {USERNAME_MINIMUM_LENGTH} and "
                f"{USERNAME_MAXIMUM_LENGTH} characters."
            ]
        if not USERNAME_PATTERN.fullmatch(username):
            return [
                "username may contain only letters, numbers, dots, hyphens, and "
                "underscores, and must start and end with a letter or number."
            ]
        if CONSECUTIVE_SEPARATORS.search(username):
            return ["username may not contain two dots, hyphens, or underscores in a row."]
        return []

    @classmethod
    def _password_errors(cls, password: str, username: str) -> list[str]:
        if len(password) < PASSWORD_MINIMUM_LENGTH:
            return [
                f"password must be at least {PASSWORD_MINIMUM_LENGTH} characters. "
                "A short sentence or phrase is the easiest way to get there, and "
                "spaces are allowed."
            ]
        if len(password) > PASSWORD_MAXIMUM_LENGTH:
            return [f"password must be {PASSWORD_MAXIMUM_LENGTH} characters or fewer."]
        if len(set(password)) == 1:
            return ["password must not be a single character repeated."]
        if username and username.lower() in password.lower():
            return ["password must not contain your username."]
        return []

    @classmethod
    def from_dictionary(cls, data: dict) -> "RegisterDTO":
        return cls(
            username=data["username"],
            password=normalize_password(data["password"]),
        )
