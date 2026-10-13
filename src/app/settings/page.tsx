import AppLayout from "@/components/AppLayout";

export default function SettingsPage() {
  return (
    <AppLayout>
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-[var(--foreground)] mb-2">
          Settings ⚙️
        </h1>
        <p className="text-[var(--muted-foreground)] mb-8">
          Manage your account and preferences
        </p>

        <div className="space-y-6">
          {/* Profile Section */}
          <SettingsSection title="Profile">
            <div className="space-y-4">
              <SettingsInput label="Full Name" value="User" />
              <SettingsInput label="Email" value="user@example.com" type="email" />
              <SettingsInput label="Timezone" value="UTC+07:00 (Bangkok)" disabled />
            </div>
          </SettingsSection>

          {/* Appearance Section */}
          <SettingsSection title="Appearance">
            <div className="space-y-4">
              <SettingsToggle label="Dark Mode" description="Use dark theme" enabled={false} />
              <SettingsToggle label="Compact View" description="Reduce spacing in lists" enabled={false} />
            </div>
          </SettingsSection>

          {/* AI Features Section */}
          <SettingsSection title="AI Features">
            <div className="space-y-4">
              <SettingsToggle
                label="AI Daily Planning"
                description="Let AI suggest task priorities"
                enabled={true}
              />
              <SettingsToggle
                label="Smart Notifications"
                description="AI-powered notification timing"
                enabled={true}
              />
            </div>
          </SettingsSection>

          {/* Notifications Section */}
          <SettingsSection title="Notifications">
            <div className="space-y-4">
              <SettingsToggle label="Email Notifications" description="Daily digest emails" enabled={true} />
              <SettingsToggle label="Push Notifications" description="Browser notifications" enabled={false} />
            </div>
          </SettingsSection>

          {/* Danger Zone */}
          <div className="bg-red-50 rounded-2xl p-6 border border-red-200">
            <h3 className="text-lg font-semibold text-red-600 mb-4">
              Danger Zone
            </h3>
            <button className="px-4 py-2 bg-red-100 text-red-600 rounded-xl font-medium hover:bg-red-200 transition-colors">
              Delete Account
            </button>
          </div>

          {/* Save Button */}
          <div className="flex justify-end">
            <button className="px-8 py-3 bg-[var(--primary)] text-white rounded-xl font-medium hover:opacity-90 transition-opacity">
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </AppLayout>
  );
}

function SettingsSection({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="bg-white rounded-2xl p-6 shadow-sm border border-[var(--border)]">
      <h2 className="text-lg font-semibold text-[var(--foreground)] mb-4">
        {title}
      </h2>
      {children}
    </div>
  );
}

function SettingsInput({
  label,
  value,
  type = "text",
  disabled = false,
}: {
  label: string;
  value: string;
  type?: string;
  disabled?: boolean;
}) {
  return (
    <div>
      <label className="block text-sm font-medium text-[var(--foreground)] mb-2">
        {label}
      </label>
      <input
        type={type}
        defaultValue={value}
        disabled={disabled}
        className={`
          w-full px-4 py-3 rounded-xl border border-[var(--border)]
          focus:outline-none focus:ring-2 focus:ring-[var(--ring)]
          ${disabled ? "bg-[var(--muted)] text-[var(--muted-foreground)]" : "bg-white"}
        `}
      />
    </div>
  );
}

function SettingsToggle({
  label,
  description,
  enabled,
}: {
  label: string;
  description: string;
  enabled: boolean;
}) {
  return (
    <div className="flex items-center justify-between">
      <div>
        <h4 className="font-medium text-[var(--foreground)]">{label}</h4>
        <p className="text-sm text-[var(--muted-foreground)]">{description}</p>
      </div>
      <button
        className={`
          w-14 h-8 rounded-full transition-colors relative
          ${enabled ? "bg-[var(--primary)]" : "bg-[var(--muted)]"}
        `}
      >
        <span
          className={`
            absolute top-1 w-6 h-6 bg-white rounded-full shadow-sm transition-all
            ${enabled ? "left-7" : "left-1"}
          `}
        />
      </button>
    </div>
  );
}
