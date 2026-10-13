import AppLayout from "@/components/AppLayout";

export default function MyDayPage() {
  return (
    <AppLayout>
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
          My Day ☀️
        </h1>
        <p className="text-[var(--muted-foreground)] mb-8">
          Focus on what matters today
        </p>

        {/* Today's Tasks */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)] mb-6">
          <h2 className="text-xl font-semibold text-[var(--foreground)] mb-4">
            Today&apos;s Tasks
          </h2>
          <div className="space-y-3">
            <TaskItem title="Review design mockups" time="9:00 AM" priority="high" />
            <TaskItem title="Team standup meeting" time="10:00 AM" priority="medium" />
            <TaskItem title="Update project documentation" time="2:00 PM" priority="low" />
            <TaskItem title="Code review for PR #42" time="4:00 PM" priority="medium" />
          </div>
        </div>

        {/* AI Suggestions */}
        <div className="bg-gradient-to-r from-orange-400 to-pink-500 rounded-2xl p-6 text-white">
          <div className="flex items-center gap-3 mb-3">
            <span className="text-2xl">🤖</span>
            <h3 className="text-lg font-semibold">AI Suggestion</h3>
          </div>
          <p className="text-white/90">
            You have 3 high-priority tasks today. Consider tackling &quot;Review design mockups&quot; first
            while your mind is fresh.
          </p>
        </div>
      </div>
    </AppLayout>
  );
}

function TaskItem({
  title,
  time,
  priority,
}: {
  title: string;
  time: string;
  priority: "high" | "medium" | "low";
}) {
  const priorityColors = {
    high: "bg-red-100 text-red-600",
    medium: "bg-yellow-100 text-yellow-600",
    low: "bg-green-100 text-green-600",
  };

  return (
    <div className="flex items-center gap-4 p-4 rounded-xl bg-[var(--muted)] hover:bg-[var(--sidebar-hover)] transition-colors">
      <input
        type="checkbox"
        className="w-5 h-5 rounded border-[var(--border)] text-[var(--primary)] focus:ring-[var(--ring)]"
      />
      <div className="flex-1">
        <h3 className="font-medium text-[var(--foreground)]">{title}</h3>
        <p className="text-sm text-[var(--muted-foreground)]">{time}</p>
      </div>
      <span className={`px-3 py-1 rounded-full text-xs font-medium ${priorityColors[priority]}`}>
        {priority}
      </span>
    </div>
  );
}
