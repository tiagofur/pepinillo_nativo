package services

import "net/mail"

func isValidEmail(email string) bool {
	_, err := mail.ParseAddress(email)
	return err == nil
}

func isStrongPassword(password string) bool {
	return len(password) >= 8 && len(password) <= 72
}
