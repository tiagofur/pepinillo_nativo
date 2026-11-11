package domain

// InternalStats is the aggregate-only payload served to the CRM metrics
// collector. It must never carry PII (emails, names, ids, task content).
// Every figure is computed over users who explicitly opted in
// (User.MetricsOptIn); everyone else is excluded entirely.
type InternalStats struct {
	Users        InternalStatsUsers  `json:"users"`
	Sessions     InternalStatsByMode `json:"sessions"`
	FocusMinutes InternalStatsByMode `json:"focusMinutes"`
	BreakMinutes InternalStatsBreak  `json:"breakMinutes"`
	Tasks        InternalStatsTasks  `json:"tasks"`
}

type InternalStatsUsers struct {
	Total     int64 `json:"total"`
	New30d    int64 `json:"new30d"`
	Active7d  int64 `json:"active7d"`
	Active30d int64 `json:"active30d"`
}

// InternalStatsByMode is shared by sessions and focusMinutes; the total key
// name differs per the contract, so it is marshalled via the Total30d field.
type InternalStatsByMode struct {
	Total30d  int64            `json:"total30d"`
	ByMode30d map[string]int64 `json:"byMode30d"`
}

type InternalStatsBreak struct {
	Total30d int64 `json:"total30d"`
}

type InternalStatsTasks struct {
	Created30d   int64 `json:"created30d"`
	Completed30d int64 `json:"completed30d"`
}
