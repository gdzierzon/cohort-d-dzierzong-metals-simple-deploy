from flask import Flask

from routes.alloy_element_routes import alloy_element_blueprint
from routes.alloy_routes import alloy_blueprint
from routes.coin_routes import coin_blueprint
from routes.element_routes import element_blueprint


def create_app() -> Flask:
    app = Flask(__name__)

    app.register_blueprint(element_blueprint)
    app.register_blueprint(alloy_blueprint)
    app.register_blueprint(alloy_element_blueprint)
    app.register_blueprint(coin_blueprint)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(debug=True)
