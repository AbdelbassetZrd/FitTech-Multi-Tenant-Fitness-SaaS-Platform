# Backend Environment Variables Guide

This guide explains how to set up and configure the environment variables required for the FitTech backend application.

## 🚀 Getting Started

To get started, you need to create a `.env` file in the root of the `backend` directory.

You can create this file manually or copy the provided structure below. **Never commit the `.env` file to version control, as it contains sensitive credentials.**

---

## 📄 `.env` File Template

Copy the following block and paste it into your newly created `.env` file. Replace the placeholder values with your actual local or production credentials.

```env
# Django Security
SECRET_KEY=your-secret-key-here-do-not-share

# Database Configuration (MySQL/PostgreSQL)
DB_NAME=fittech_db
DB_USER=root
DB_PASSWORD=your_database_password
DB_HOST=127.0.0.1
DB_PORT=3308

# Email / SMTP Configuration
EMAIL_HOST_USER=your_email@gmail.com
EMAIL_HOST_PASSWORD=your_email_app_password

# Optional/Alternative SMTP Server (e.g. Mailtrap)
SMTP_USERNAME=your_smtp_username
SMTP_USERPASS=your_smtp_password
SMTP_PORT=2525

# Frontend URL for CORS / Email Links
FRONTEND_URL=http://localhost:3000
```

---

## 📖 Variables Explanation

### Django Security
- `SECRET_KEY`: A long, random string used by Django for cryptographic signing. It should be kept secret. In production, ensure this is a strong, unpredictable value.

### Database Configuration
- `DB_NAME`: The name of your local database (e.g., `fittech_db`).
- `DB_USER`: The username used to connect to your database (often `root` locally).
- `DB_PASSWORD`: The password for your database user.
- `DB_HOST`: The host where your database is running. Use `127.0.0.1` or `localhost` for local development.
- `DB_PORT`: The port your database is listening on. Default is usually `3306` for MySQL, or `5432` for PostgreSQL. The example uses `3308`.

### Email / SMTP Configuration
- `EMAIL_HOST_USER` & `EMAIL_HOST_PASSWORD`: Used for sending emails (e.g., user registration, password resets). If using Gmail, you will need to generate an "App Password" in your Google Account settings.
- `SMTP_USERNAME`, `SMTP_USERPASS`, `SMTP_PORT`: If you are using an alternative SMTP service like Mailtrap for testing, use these values to configure the connection. (Oftenport `2525` is used for testing).

### Frontend Connection
- `FRONTEND_URL`: The URL where the frontend is running. This is used to allow CORS requests and to generate absolute URLs sent in emails (like password reset links). Typically `http://localhost:3000` in local development.

---

## ❓ Troubleshooting

- **Database Connection Error**: Double-check `DB_HOST` and `DB_PORT` and make sure your database server is running.
- **Emails not sending**: Ensure you're using an "App Password" instead of your regular password if using `gmail.com`. If testing with Mailtrap, verify credentials match your Mailtrap inbox settings.

---

## 🐳 Docker Compose Database Setup

This project includes a `docker-compose.yml` file to quickly spin up a MySQL database for local development.

### 1. Match your `.env` variables
Ensure the database credentials in your `.env` match the configurations in `docker-compose.yml`. Based on the current Compose file, you should use:
- `DB_USER=root`
- `DB_PASSWORD=ibrahim12345` (matching `MYSQL_ROOT_PASSWORD`)
- `DB_NAME=fittech_db` (matching `MYSQL_DATABASE`)
- `DB_HOST=127.0.0.1`
- `DB_PORT=3308` (mapped to internal `3306`)

### 2. Start the database

Run the following command in the `backend` directory to start the database container in detached mode:

```bash
docker compose up -d
```

### 3. Verify the container is running

You can check if the database is running and healthy with:

```bash
docker compose ps
```

To stop the database when you are done, run:
```bash
docker compose down
```
