import AppLayout from "@/components/AppLayout";

export default function TasksPage() {
  return (
    <AppLayout>
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
              Tasks ✅
            </h1>
            <p className="text-[var(--muted-foreground)]">
              Kanban board for task management
            </p>
          </div>
          <button className="px-6 py-3 bg-[var(--primary)] text-white rounded-xl font-medium hover:opacity-90 transition-opacity">
            + Add Task
          </button>
        </div>

        {/* Kanban Board */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* To Do Column */}
          <KanbanColumn title="To Do" color="bg-gray-100" tasks={[
            { title: "Research competitors", priority: "medium", assignee: "A" },
            { title: "Create wireframes", priority: "high", assignee: "B" },
            { title: "Setup CI/CD pipeline", priority: "low", assignee: "C" },
          ]} />

          {/* In Progress Column */}
          <KanbanColumn title="In Progress" color="bg-blue-100" tasks={[
            { title: "Implement authentication", priority: "high", assignee: "A" },
            { title: "Design landing page", priority: "medium", assignee: "D" },
          ]} />

          {/* Done Column */}
          <KanbanColumn title="Done" color="bg-green-100" tasks={[
            { title: "Project setup", priority: "low", assignee: "A" },
            { title: "Database schema", priority: "high", assignee: "B" },
            { title: "API endpoints", priority: "medium", assignee: "C" },
          ]} />
        </div>
      </div>
    </AppLayout>
  );
}

function KanbanColumn({
  title,
  color,
  tasks,
}: {
  title: string;
  color: string;
  tasks: Array<{ title: string; priority: string; assignee: string }>;
}) {
  return (
    <div className="flex flex-col">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-semibold text-[var(--foreground)]">{title}</h2>
        <span className={`px-2 py-1 rounded-full text-xs font-medium ${color}`}>
          {tasks.length}
        </span>
      </div>
      <div className="flex-1 space-y-3">
        {tasks.map((task, index) => (
          <KanbanCard key={index} {...task} />
        ))}
        <button className="w-full p-3 border-2 border-dashed border-[var(--border)] rounded-xl text-[var(--muted-foreground)] hover:border-[var(--primary)] hover:text-[var(--primary)] transition-colors">
          + Add task
        </button>
      </div>
    </div>
  );
}

function KanbanCard({
  title,
  priority,
  assignee,
}: {
  title: string;
  priority: string;
  assignee: string;
}) {
  const priorityColors: Record<string, string> = {
    high: "bg-red-100 text-red-600",
    medium: "bg-yellow-100 text-yellow-600",
    low: "bg-green-100 text-green-600",
  };

  return (
    <div className="bg-white rounded-xl p-4 shadow-sm border border-[var(--border)] hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-3">
        <span className={`px-2 py-1 rounded-full text-xs font-medium ${priorityColors[priority]}`}>
          {priority}
        </span>
        <div className="w-7 h-7 rounded-full bg-[var(--secondary)] flex items-center justify-center text-white text-xs font-medium">
          {assignee}
        </div>
      </div>
      <h3 className="font-medium text-[var(--foreground)]">{title}</h3>
    </div>
  );
}
