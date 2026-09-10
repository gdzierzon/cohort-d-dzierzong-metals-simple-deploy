from dataclasses import dataclass


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
        if not isinstance(data.get("password"), str) or not data["password"]:
            errors.append("password is required.")
        return errors

    @classmethod
    def from_dictionary(cls, data: dict) -> "LoginDTO":
        return cls(username=data["username"], password=data["password"])


@dataclass
class RegisterDTO(LoginDTO):
    @classmethod
    def validate(cls, data: object) -> list[str]:
        errors = super().validate(data)
        if errors or not isinstance(data, dict):
            return errors

        username = data["username"].strip()
        if not 3 <= len(username) <= 100:
            errors.append("username must be between 3 and 100 characters.")
        elif not username.replace("_", "").replace("-", "").isalnum():
            errors.append("username may contain only letters, numbers, hyphens, and underscores.")
        return errors

    @classmethod
    def from_dictionary(cls, data: dict) -> "RegisterDTO":
        return cls(username=data["username"], password=data["password"])
