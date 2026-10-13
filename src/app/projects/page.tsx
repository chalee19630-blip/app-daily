import AppLayout from "@/components/AppLayout";

export default function ProjectsPage() {
  return (
    <AppLayout>
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
              Projects 📁
            </h1>
            <p className="text-[var(--muted-foreground)]">
              Manage all your projects in one place
            </p>
          </div>
          <button className="px-6 py-3 bg-[var(--primary)] text-white rounded-xl font-medium hover:opacity-90 transition-opacity">
            + New Project
          </button>
        </div>

        {/* Project Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <ProjectCard
            name="Website Redesign"
            description="Complete overhaul of company website"
            progress={65}
            members={4}
            color="bg-blue-500"
          />
          <ProjectCard
            name="Mobile App MVP"
            description="Cross-platform mobile application"
            progress={45}
            members={3}
            color="bg-green-500"
          />
          <ProjectCard
            name="Marketing Campaign"
            description="Q4 marketing initiative"
            progress={100}
            members={6}
            color="bg-purple-500"
          />
          <ProjectCard
            name="API Integration"
            description="Third-party API connections"
            progress={20}
            members={2}
            color="bg-orange-500"
          />
          <ProjectCard
            name="Data Analytics Dashboard"
            description="Real-time analytics visualization"
            progress={80}
            members={5}
            color="bg-pink-500"
          />
          <ProjectCard
            name="Security Audit"
            description="Annual security review"
            progress={10}
            members={2}
            color="bg-red-500"
          />
        </div>
      </div>
    </AppLayout>
  );
}

function ProjectCard({
  name,
  description,
  progress,
  members,
  color,
}: {
  name: string;
  description: string;
  progress: number;
  members: number;
  color: string;
}) {
  return (
    <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)] hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between mb-4">
        <div className={`w-12 h-12 rounded-xl ${color} flex items-center justify-center text-white text-xl`}>
          📁
        </div>
        <span className="text-sm font-medium text-[var(--muted-foreground)]">
          {progress}%
        </span>
      </div>
      <h3 className="text-lg font-semibold text-[var(--foreground)] mb-2">
        {name}
      </h3>
      <p className="text-sm text-[var(--muted-foreground)] mb-4">
        {description}
      </p>
      <div className="flex items-center justify-between">
        <div className="w-full h-2 bg-[var(--muted)] rounded-full overflow-hidden mr-4">
          <div
            className={`h-full ${color} rounded-full transition-all`}
            style={{ width: `${progress}%` }}
          />
        </div>
        <div className="flex -space-x-2">
          {Array.from({ length: Math.min(members, 3) }).map((_, i) => (
            <div
              key={i}
              className="w-8 h-8 rounded-full bg-[var(--secondary)] border-2 border-white flex items-center justify-center text-xs text-white font-medium"
            >
              {String.fromCharCode(65 + i)}
            </div>
          ))}
          {members > 3 && (
            <div className="w-8 h-8 rounded-full bg-[var(--muted)] border-2 border-white flex items-center justify-center text-xs text-[var(--muted-foreground)] font-medium">
              +{members - 3}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
