import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text

app = Flask(__name__)

# Configure the SQLAlchemy database URI
app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{os.environ['DB_USER']}:{os.environ['DB_PASSWORD']}@{os.environ['DB_HOST']}/{os.environ['DB_NAME']}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False  # To suppress a warning

# Initialize SQLAlchemy
db = SQLAlchemy(app)

@app.route('/')
def hello_world():
    try:
        # Use the `text()` construct to execute a raw SQL query
        with db.engine.connect() as connection:
            result = connection.execute(text("SELECT 'Hello World!'")).fetchone()
            return str(result[0])
    except Exception as e:
        return f"Error connecting to the database: {str(e)}"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=3000)
