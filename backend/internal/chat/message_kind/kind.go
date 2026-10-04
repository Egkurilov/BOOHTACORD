package messagekind

const User = "USER"
const SystemWelcome = "SYSTEM_WELCOME"

func OrUser(kind string) string {
	if kind == SystemWelcome {
		return SystemWelcome
	}
	return User
}
