# Frontend Environment Variables Guide

This guide explains how to set up and configure the environment variables required for the FitTech Next.js frontend application.

## 🚀 Getting Started

In Next.js, environment variables should be stored in a `.env.local` file at the root of the `frontend` directory.

**Note:** The `.env.local` file is automatically ignored by Git due to the `.gitignore` configuration in Next.js projects. **Do not commit this file to version control.**

---

## 📄 `.env.local` File Template

Create a file named `.env.local` in the `frontend` directory, copy the following block, and paste it into the file. Modify the values if necessary.

```env
# Backend API URL
NEXT_PUBLIC_API_URL=http://localhost:8000
```

---

## 📖 Variables Explanation

### Backend API URL
- `NEXT_PUBLIC_API_URL`: This specifies the base URL of your backend API. Whenever the frontend makes requests (like login, signup, fetch data), it uses this URL.
  - By default, during local development, your Django backend runs on `http://localhost:8000`.
  - The `NEXT_PUBLIC_` prefix is fully intentional and necessary! In Next.js, only variables prefixed with `NEXT_PUBLIC_` are exposed to the browser (client-side). If you omit this prefix, the variable will only be available in server-side code and will evaluate to `undefined` in client components.

---

## ❓ Troubleshooting

- **Network Errors / API Not Found**: Ensure that your backend Django server is actually running on the port specified in `NEXT_PUBLIC_API_URL`.
- **Undefined API URL on Client**: Make sure you did not remove the `NEXT_PUBLIC_` prefix and that you restarted the Next.js development server after creating or updating the `.env.local` file.
