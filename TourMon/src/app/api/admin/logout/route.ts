import { NextResponse } from "next/server";
import { ADMIN_BASE_URL, ADMIN_SESSION_COOKIE } from "@/lib/admin/server-session";

export async function POST() {
  const response = NextResponse.redirect(new URL("/admin/login", ADMIN_BASE_URL));
  response.cookies.delete(ADMIN_SESSION_COOKIE);
  return response;
}
