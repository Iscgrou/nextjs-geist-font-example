# VPN Billing System

## Installation

1. Clone this repository:
```bash
git clone https://github.com/Iscgrou/finone.git
cd finone
```

2. Run the installation script:
```bash
./scripts/install.sh
```

## Environment Variables

The following environment variables need to be set in `.env`:

- `DATABASE_URL`: PostgreSQL connection URL (format: `postgresql://user:password@localhost:5432/dbname`)
- `NODE_ENV`: Set to `production` for production environment
- `DOMAIN`: Your domain name
- `ADMIN_EMAIL`: Administrator email address
- `ADMIN_USERNAME`: Administrator username
- `ADMIN_PASSWORD`: Administrator password
- `TELEGRAM_BOT_TOKEN`: Telegram bot token (optional)
- `OPENAI_API_KEY`: OpenAI API key (optional)
- `GOOGLE_DRIVE_EMAIL`: Google Drive email (optional)

## Services

The system uses the following services:

- PostgreSQL: Database server
- Nginx: Web server and reverse proxy
- Node.js: Application server

## Starting the Application

```bash
cd /opt/vpn-billing
npm run start
```

Access the application at `http://your-domain`

## Development

For development, use:

```bash
npm run dev
```

This will start the development server with hot reloading enabled.
