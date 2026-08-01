## PR Checklist

- [ ] I avoided using `Container` directly where possible.
- [ ] I used `AppScreen` for the root layer of my new feature route.
- [ ] I ensured all layout borders and styling are fetched natively from `design_system/design_system.dart` components.
- [ ] I did NOT hardcode inline colors (`Colors.blue`) or edge insets (`EdgeInsets.all(16)`).
- [ ] If I created an entirely new universal component, I proposed it properly inside the `design_system/components/` folder and added it to `RFC_DECISION_LOG.md`.
