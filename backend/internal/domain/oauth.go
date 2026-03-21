package domain

type LinkedProviders struct {
	HasPassword bool           `json:"hasPassword"`
	Google      *OAuthProvider `json:"google,omitempty"`
	Apple       *OAuthProvider `json:"apple,omitempty"`
}

type OAuthProvider struct {
	ID       string `json:"id"`
	Email    string `json:"email"`
	Name     string `json:"name"`
	Picture  string `json:"picture,omitempty"`
	LinkedAt string `json:"linkedAt"`
}

type GoogleUserInfo struct {
	ID            string `json:"sub"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
}

type AppleUserInfo struct {
	Sub           string     `json:"sub"`
	Email         string     `json:"email"`
	EmailVerified bool       `json:"email_verified"`
	Name          *AppleName `json:"name,omitempty"`
}

type AppleName struct {
	FirstName string `json:"firstName"`
	LastName  string `json:"lastName"`
}
