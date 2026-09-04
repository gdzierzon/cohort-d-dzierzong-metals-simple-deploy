class BusinessValidationError(Exception):
    def __init__(self, errors: list[str]):
        super().__init__("Business validation failed.")
        self.errors = errors
