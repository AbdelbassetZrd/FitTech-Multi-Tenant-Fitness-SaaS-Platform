import type { NextConfig } from "next";

const DJANGO_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  process.env.API_BASE_URL ||
  "https://providing-april-manger.ngrok-free.dev";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${DJANGO_URL}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
