import AppLayout from "@/components/AppLayout";

export default function Home() {
  return (
    <AppLayout>
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
            Welcome to ProjectPilot AI
          </h1>
          <p className="text-[var(--muted-foreground)]">
            Manage your projects and tasks with AI assistance
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard title="Active Projects" value="5" icon="📁" color="bg-blue-100 text-blue-600" />
          <StatCard title="Tasks Today" value="12" icon="✅" color="bg-green-100 text-green-600" />
          <StatCard title="Completed" value="28" icon="🎉" color="bg-purple-100 text-purple-600" />
          <StatCard title="AI Suggestions" value="3" icon="🤖" color="bg-orange-100 text-orange-600" />
        </div>

        {/* Recent Projects */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)] mb-6">
          <h2 className="text-xl font-semibold text-[var(--foreground)] mb-4">
            Recent Projects
          </h2>
          <div className="space-y-4">
            <ProjectItem name="Website Redesign" tasks={8} completed={5} />
            <ProjectItem name="Mobile App MVP" tasks={15} completed={9} />
            <ProjectItem name="Marketing Campaign" tasks={6} completed={6} />
          </div>
        </div>

        {/* AI Assistant Card */}
        <div className="bg-gradient-to-r from-[var(--primary)] to-[var(--accent)] rounded-2xl p-6 text-white">
          <div className="flex items-start gap-4">
            <div className="text-4xl">🤖</div>
            <div className="flex-1">
              <h3 className="text-lg font-semibold mb-2">
                AI Daily Planning
              </h3>
              <p className="text-white/80 mb-4">
                Let AI help you organize your day based on priorities and deadlines.
              </p>
              <button className="px-4 py-2 bg-white text-[var(--primary)] rounded-xl font-medium hover:bg-white/90 transition-colors">
                Plan My Day
              </button>
            </div>
          </div>
        </div>
      </div>
    </AppLayout>
  );
}

function StatCard({
  title,
  value,
  icon,
  color,
}: {
  title: string;
  value: string;
  icon: string;
  color: string;
}) {
  return (
    <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)]">
      <div className="flex items-center justify-between mb-4">
        <span className="text-sm text-[var(--muted-foreground)]">{title}</span>
        <div className={`w-10 h-10 rounded-xl ${color} flex items-center justify-center`}>
          <span className="text-lg">{icon}</span>
        </div>
      </div>
      <p className="text-3xl font-bold text-[var(--foreground)]">{value}</p>
    </div>
  );
}

function ProjectItem({
  name,
  tasks,
  completed,
}: {
  name: string;
  tasks: number;
  completed: number;
}) {
  const progress = Math.round((completed / tasks) * 100);
  return (
    <div className="flex items-center gap-4 p-4 rounded-xl bg-[var(--muted)] hover:bg-[var(--sidebar-hover)] transition-colors">
      <div className="flex-1">
        <h3 className="font-medium text-[var(--foreground)]">{name}</h3>
        <p className="text-sm text-[var(--muted-foreground)]">
          {completed}/{tasks} tasks completed
        </p>
      </div>
      <div className="flex items-center gap-3">
        <div className="w-24 h-2 bg-white rounded-full overflow-hidden">
          <div
            className="h-full bg-[var(--primary)] rounded-full transition-all"
            style={{ width: `${progress}%` }}
          />
        </div>
        <span className="text-sm font-medium text-[var(--foreground)] w-12 text-right">
          {progress}%
        </span>
      </div>
    </div>
  );
}
