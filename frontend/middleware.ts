import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

// Routes that require authentication
const protectedPaths = ["/dashboard", "/profile", "/settings"];

// Routes that should redirect to home if already authenticated
const authPaths = ["/login", "/register", "/reset-password"];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Check if the user has an auth token stored (via cookie set from client)
  const hasToken = request.cookies.get("fittech_authenticated")?.value === "true";

  // Redirect unauthenticated users away from protected routes
  const isProtected = protectedPaths.some((path) => pathname.startsWith(path));
  if (isProtected && !hasToken) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Redirect authenticated users away from auth pages
  const isAuthPage = authPaths.some((path) => pathname === path);
  if (isAuthPage && hasToken) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/profile/:path*",
    "/settings/:path*",
    "/login",
    "/register",
    "/reset-password",
  ],
};
