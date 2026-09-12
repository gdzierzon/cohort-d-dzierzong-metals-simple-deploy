import os

from flask import Flask

from routes.auth_routes import auth_blueprint
from routes.alloy_element_routes import alloy_element_blueprint
from routes.alloy_routes import alloy_blueprint
from routes.mint_product_routes import coin_blueprint, mint_product_blueprint
from routes.element_routes import element_blueprint
from routes.user_routes import user_blueprint


def create_app() -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(
        JWT_SECRET_KEY=os.getenv("JWT_SECRET_KEY"),
        JWT_EXPIRATION_MINUTES=int(os.getenv("JWT_EXPIRATION_MINUTES", "60")),
        REFRESH_ROLES_ON_AUTHORIZATION=True,
    )

    app.register_blueprint(auth_blueprint)
    app.register_blueprint(element_blueprint)
    app.register_blueprint(alloy_blueprint)
    app.register_blueprint(alloy_element_blueprint)
    app.register_blueprint(mint_product_blueprint)
    app.register_blueprint(coin_blueprint)
    app.register_blueprint(user_blueprint)

    @app.get("/health")
    def health():
        """Report HTTP server liveness without requiring database access."""
        return {"status": "ok"}, 200

    @app.after_request
    def allow_cross_origin_requests(response):
        """Allow browser requests from any origin."""
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        return response

    return app


app = create_app()


if __name__ == "__main__":
    app.run(debug=True)
