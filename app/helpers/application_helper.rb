module ApplicationHelper
  AVATAR_COLORS = %w[ bg-amber-600 bg-emerald-600 bg-sky-600 bg-rose-600 bg-violet-600 bg-teal-600 ].freeze

  # "system" follows the device's light/dark setting (see the dark variant in app/assets/tailwind/application.css).
  def current_theme
    Current.user&.theme || "system"
  end

  # A colored circle with the user's first letter. A given username always gets the same color.
  def avatar_for(user, size: "size-10 text-base")
    tag.span user.username.first.upcase, aria: { hidden: true }, class: [
      "inline-flex shrink-0 items-center justify-center rounded-full font-semibold text-white",
      size, AVATAR_COLORS[user.username.sum % AVATAR_COLORS.size]
    ]
  end
end
