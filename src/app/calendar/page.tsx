import AppLayout from "@/components/AppLayout";

export default function CalendarPage() {
  return (
    <AppLayout>
      <div className="max-w-6xl mx-auto">
        <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
          Calendar 📅
        </h1>
        <p className="text-[var(--muted-foreground)] mb-8">
          View and schedule your tasks
        </p>

        <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)]">
          {/* Calendar Header */}
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold text-[var(--foreground)]">
              October 2026
            </h2>
            <div className="flex gap-2">
              <button className="px-4 py-2 rounded-xl border border-[var(--border)] hover:bg-[var(--muted)] transition-colors">
                ←
              </button>
              <button className="px-4 py-2 rounded-xl border border-[var(--border)] hover:bg-[var(--muted)] transition-colors">
                Today
              </button>
              <button className="px-4 py-2 rounded-xl border border-[var(--border)] hover:bg-[var(--muted)] transition-colors">
                →
              </button>
            </div>
          </div>

          {/* Calendar Grid */}
          <div className="grid grid-cols-7 gap-1 mb-2">
            {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((day) => (
              <div
                key={day}
                className="text-center text-sm font-medium text-[var(--muted-foreground)] py-2"
              >
                {day}
              </div>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1">
            {/* September days */}
            {[27, 28, 29, 30].map((day) => (
              <CalendarDay key={`sep-${day}`} day={day} isOtherMonth />
            ))}
            {/* October days */}
            {Array.from({ length: 31 }, (_, i) => i + 1).map((day) => (
              <CalendarDay key={day} day={day} isToday={day === 12} hasEvents={[5, 10, 12, 15, 20, 25].includes(day)} />
            ))}
            {/* November days */}
            {[1, 2, 3, 4, 5, 6, 7].map((day) => (
              <CalendarDay key={`nov-${day}`} day={day} isOtherMonth />
            ))}
          </div>
        </div>

        {/* Upcoming Events */}
        <div className="mt-6 bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)]">
          <h3 className="text-lg font-semibold text-[var(--foreground)] mb-4">
            Upcoming Events
          </h3>
          <div className="space-y-3">
            <EventItem title="Team standup" date="Oct 13, 10:00 AM" color="bg-blue-500" />
            <EventItem title="Sprint review" date="Oct 15, 2:00 PM" color="bg-green-500" />
            <EventItem title="Client call" date="Oct 16, 11:00 AM" color="bg-purple-500" />
          </div>
        </div>
      </div>
    </AppLayout>
  );
}

function CalendarDay({
  day,
  isOtherMonth = false,
  isToday = false,
  hasEvents = false,
}: {
  day: number;
  isOtherMonth?: boolean;
  isToday?: boolean;
  hasEvents?: boolean;
}) {
  return (
    <div
      className={`
        aspect-square p-2 rounded-xl flex flex-col items-center justify-center
        ${isOtherMonth ? "text-[var(--muted-foreground)] opacity-40" : "text-[var(--foreground)]"}
        ${isToday ? "bg-[var(--primary)] text-white font-bold" : "hover:bg-[var(--muted)]"}
        transition-colors cursor-pointer
      `}
    >
      <span className="text-sm">{day}</span>
      {hasEvents && !isToday && (
        <span className="w-1.5 h-1.5 rounded-full bg-[var(--primary)] mt-1" />
      )}
    </div>
  );
}

function EventItem({
  title,
  date,
  color,
}: {
  title: string;
  date: string;
  color: string;
}) {
  return (
    <div className="flex items-center gap-4 p-4 rounded-xl bg-[var(--muted)] hover:bg-[var(--sidebar-hover)] transition-colors">
      <div className={`w-3 h-3 rounded-full ${color}`} />
      <div className="flex-1">
        <h4 className="font-medium text-[var(--foreground)]">{title}</h4>
        <p className="text-sm text-[var(--muted-foreground)]">{date}</p>
      </div>
    </div>
  );
}
