"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/providers/AuthProvider";

const navItems = [
  { href: "/", label: "Dashboard", icon: "📊" },
  { href: "/my-day", label: "My Day", icon: "☀️" },
  { href: "/projects", label: "Projects", icon: "📁" },
  { href: "/tasks", label: "Tasks", icon: "✅" },
  { href: "/calendar", label: "Calendar", icon: "📅" },
  { href: "/settings", label: "Settings", icon: "⚙️" },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, loading, signOut } = useAuth();

  const handleSignOut = async () => {
    await signOut();
    router.push("/login");
  };

  // Get user display name
  const displayName = user?.user_metadata?.full_name || user?.email?.split("@")[0] || "User";
  const initials = displayName.charAt(0).toUpperCase();

  return (
    <aside className="w-64 min-h-screen bg-white border-r border-[var(--border)] flex flex-col">
      {/* Logo */}
      <div className="p-6 border-b border-[var(--border)]">
        <Link href="/" className="flex items-center gap-2">
          <span className="text-2xl">🚀</span>
          <span className="text-xl font-bold text-[var(--foreground)]">
            ProjectPilot
          </span>
        </Link>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4">
        <ul className="space-y-2">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={`
                    flex items-center gap-3 px-4 py-3 rounded-xl
                    transition-colors duration-200
                    ${
                      isActive
                        ? "bg-[var(--primary)] text-white font-medium"
                        : "text-[var(--muted-foreground)] hover:bg-[var(--sidebar-hover)] hover:text-[var(--foreground)]"
                    }
                  `}
                >
                  <span className="text-lg">{item.icon}</span>
                  <span>{item.label}</span>
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* User section */}
      <div className="p-4 border-t border-[var(--border)]">
        {loading ? (
          <div className="flex items-center gap-3 px-4 py-3 rounded-xl bg-[var(--muted)]">
            <div className="w-10 h-10 rounded-full bg-[var(--muted-foreground)]/20 animate-pulse" />
            <div className="flex-1 min-w-0">
              <div className="h-4 bg-[var(--muted-foreground)]/20 rounded animate-pulse mb-1" />
              <div className="h-3 bg-[var(--muted-foreground)]/20 rounded animate-pulse w-20" />
            </div>
          </div>
        ) : user ? (
          <div className="flex items-center gap-3 px-4 py-3 rounded-xl bg-[var(--muted)]">
            <div className="w-10 h-10 rounded-full bg-[var(--secondary)] flex items-center justify-center text-white font-medium">
              {initials}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-[var(--foreground)] truncate">
                {displayName}
              </p>
              <p className="text-xs text-[var(--muted-foreground)] truncate">
                Free Plan
              </p>
            </div>
            <button
              onClick={handleSignOut}
              className="p-2 rounded-lg hover:bg-red-100 text-[var(--muted-foreground)] hover:text-red-600 transition-colors"
              title="Sign out"
            >
              <svg
                className="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"
                />
              </svg>
            </button>
          </div>
        ) : (
          <Link
            href="/login"
            className="flex items-center justify-center gap-2 px-4 py-3 rounded-xl bg-[var(--primary)] text-white font-medium hover:opacity-90 transition-opacity"
          >
            Sign In
          </Link>
        )}
      </div>
    </aside>
  );
}
