package notifier

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
	"os"

	"pepinillo/backend/internal/observability"
	"strings"

	"github.com/sendgrid/sendgrid-go"
	"github.com/sendgrid/sendgrid-go/helpers/mail"

	"pepinillo/backend/internal/ports"
)

type SendGridNotifier struct {
	apiKey    string
	fromEmail string
	fromName  string
	client    *sendgrid.Client
}

func NewSendGridNotifier(apiKey, fromEmail, fromName string) *SendGridNotifier {
	if apiKey == "" || fromEmail == "" {
		return nil
	}

	return &SendGridNotifier{
		apiKey:    apiKey,
		fromEmail: fromEmail,
		fromName:  fromName,
		client:    sendgrid.NewSendClient(apiKey),
	}
}

func (n *SendGridNotifier) SendPasswordResetCode(ctx context.Context, email, code string) error {
	if n == nil {
		return fmt.Errorf("sendgrid not configured")
	}

	subject := "Reset your Pepinillo password"
	plainTextContent := fmt.Sprintf("Your password reset code is: %s\n\nThis code will expire in 15 minutes.", code)
	htmlContent := n.getResetEmailTemplate(code)

	return n.sendEmail(ctx, email, subject, plainTextContent, htmlContent)
}

func (n *SendGridNotifier) SendEmailVerificationCode(ctx context.Context, email, code string) error {
	if n == nil {
		return fmt.Errorf("sendgrid not configured")
	}

	subject := "Verify your Pepinillo email"
	plainTextContent := fmt.Sprintf("Your verification code is: %s\n\nThis code will expire in 15 minutes.", code)
	htmlContent := n.getVerificationEmailTemplate(code)

	return n.sendEmail(ctx, email, subject, plainTextContent, htmlContent)
}

func (n *SendGridNotifier) SendEmailChangeVerification(ctx context.Context, oldEmail, newEmail, code string) error {
	if n == nil {
		return fmt.Errorf("sendgrid not configured")
	}

	subject := "Confirm your new email address"
	plainTextContent := fmt.Sprintf("You requested to change your email from %s to %s.\n\nYour verification code is: %s\n\nThis code will expire in 15 minutes.", oldEmail, newEmail, code)
	htmlContent := n.getEmailChangeEmailTemplate(oldEmail, newEmail, code)

	return n.sendEmail(ctx, newEmail, subject, plainTextContent, htmlContent)
}

func (n *SendGridNotifier) sendEmail(ctx context.Context, toEmail, subject, plainTextContent, htmlContent string) error {
	from := mail.NewEmail(n.fromName, n.fromEmail)
	to := mail.NewEmail("", toEmail)

	message := mail.NewSingleEmail(from, subject, to, plainTextContent, htmlContent)

	response, err := n.client.SendWithContext(ctx, message)
	if err != nil {
		slog.Error("sendgrid send failed", "error", err, "toEmail", toEmail)
		observability.CaptureError(err, map[string]string{
			"stage":    "sendgrid_send",
			"toEmail":  toEmail,
			"provider": "sendgrid",
		})
		return fmt.Errorf("failed to send email: %w", err)
	}

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		slog.Error("sendgrid non-2xx response",
			"status", response.StatusCode,
			"body", response.Body,
			"toEmail", toEmail,
		)
		return fmt.Errorf("email service returned status %d", response.StatusCode)
	}

	slog.Info("email sent", "toEmail", toEmail, "status", response.StatusCode)
	return nil
}

func (n *SendGridNotifier) getResetEmailTemplate(code string) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset your password</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .container { background: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 40px; }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 32px; font-weight: bold; color: #10B981; }
        .code { background: linear-gradient(135deg, #10B981 0%%, #059669 100%%); color: white; font-size: 36px; font-weight: bold; letter-spacing: 4px; text-align: center; padding: 20px; border-radius: 8px; margin: 30px 0; }
        .instructions { color: #666; margin-bottom: 20px; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #9ca3af; font-size: 14px; }
        .warning { background: #FEF2F2; border-left: 4px solid #EF4444; padding: 15px; margin: 20px 0; color: #991B1B; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🥒 Pepinillo</div>
        </div>
        <h2>Reset your password</h2>
        <p class="instructions">You requested to reset your password. Use the verification code below to proceed:</p>
        <div class="code">%s</div>
        <p class="instructions">This code will expire in <strong>15 minutes</strong>.</p>
        <div class="warning">
            <strong>Security notice:</strong> If you didn't request this password reset, please ignore this email and your account will remain secure.
        </div>
        <p>Need help? Contact us at <a href="mailto:support@pepinillo.app">support@pepinillo.app</a></p>
        <div class="footer">
            <p>&copy; 2026 Pepinillo. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
`, code)
}

func (n *SendGridNotifier) getVerificationEmailTemplate(code string) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify your email</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .container { background: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 40px; }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 32px; font-weight: bold; color: #10B981; }
        .code { background: linear-gradient(135deg, #10B981 0%%, #059669 100%%); color: white; font-size: 36px; font-weight: bold; letter-spacing: 4px; text-align: center; padding: 20px; border-radius: 8px; margin: 30px 0; }
        .instructions { color: #666; margin-bottom: 20px; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #9ca3af; font-size: 14px; }
        .info { background: #ECFDF5; border-left: 4px solid #10B981; padding: 15px; margin: 20px 0; color: #065F46; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🥒 Pepinillo</div>
        </div>
        <h2>Verify your email address</h2>
        <p class="instructions">Welcome to Pepinillo! Please verify your email address to complete your registration:</p>
        <div class="code">%s</div>
        <p class="instructions">This code will expire in <strong>15 minutes</strong>.</p>
        <div class="info">
            <strong>Why verify?</strong> Verifying your email helps us keep your account secure and allows you to receive important notifications.
        </div>
        <p>Need help? Contact us at <a href="mailto:support@pepinillo.app">support@pepinillo.app</a></p>
        <div class="footer">
            <p>&copy; 2026 Pepinillo. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
`, code)
}

func (n *SendGridNotifier) getEmailChangeEmailTemplate(oldEmail, newEmail, code string) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Confirm your new email</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
        .container { background: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 40px; }
        .header { text-align: center; margin-bottom: 30px; }
        .logo { font-size: 32px; font-weight: bold; color: #10B981; }
        .code { background: linear-gradient(135deg, #10B981 0%%, #059669 100%%); color: white; font-size: 36px; font-weight: bold; letter-spacing: 4px; text-align: center; padding: 20px; border-radius: 8px; margin: 30px 0; }
        .instructions { color: #666; margin-bottom: 20px; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 1px solid #e5e7eb; color: #9ca3af; font-size: 14px; }
        .warning { background: #FEF2F2; border-left: 4px solid #EF4444; padding: 15px; margin: 20px 0; color: #991B1B; }
        .email-change { background: #ECFDF5; padding: 15px; margin: 20px 0; color: #065F46; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🥒 Pepinillo</div>
        </div>
        <h2>Confirm your new email address</h2>
        <p class="instructions">You requested to change your email address. Please confirm this change:</p>
        <div class="email-change">
            <p><strong>From:</strong> %s</p>
            <p><strong>To:</strong> %s</p>
        </div>
        <p class="instructions">Use the verification code below to confirm this change:</p>
        <div class="code">%s</div>
        <p class="instructions">This code will expire in <strong>15 minutes</strong>.</p>
        <div class="warning">
            <strong>Important:</strong> Your old email (%s) will remain active until you confirm this change. If you didn't request this, please ignore this email.
        </div>
        <p>Need help? Contact us at <a href="mailto:support@pepinillo.app">support@pepinillo.app</a></p>
        <div class="footer">
            <p>&copy; 2026 Pepinillo. All rights reserved.</p>
        </div>
    </div>
</body>
</html>
`, oldEmail, newEmail, code, oldEmail)
}

func LogNotifierWithFallback(apiKey, fromEmail, fromName string) ports.Notifier {
	sendgrid := NewSendGridNotifier(apiKey, fromEmail, fromName)
	if sendgrid != nil {
		slog.Info("sendgrid notifier enabled")
		return sendgrid
	}

	slog.Info("sendgrid not configured, using log notifier")
	return NewLogNotifier()
}

type FallbackNotifier struct {
	sendgrid *SendGridNotifier
	log      *LogNotifier
}

func NewFallbackNotifier(apiKey, fromEmail, fromName string) ports.Notifier {
	sg := NewSendGridNotifier(apiKey, fromEmail, fromName)
	logNotifier := NewLogNotifier()

	if sg != nil {
		slog.Info("sendgrid notifier enabled with log fallback")
		return &FallbackNotifier{
			sendgrid: sg,
			log:      logNotifier,
		}
	}

	slog.Info("sendgrid not configured, using log notifier only")
	return logNotifier
}

func (f *FallbackNotifier) SendPasswordResetCode(ctx context.Context, email, code string) error {
	if f.sendgrid != nil {
		if err := f.sendgrid.SendPasswordResetCode(ctx, email, code); err != nil {
			slog.Warn("sendgrid failed, falling back to log notifier", "error", err)
			return f.log.SendPasswordResetCode(ctx, email, code)
		}
		return nil
	}
	return f.log.SendPasswordResetCode(ctx, email, code)
}

func (f *FallbackNotifier) SendEmailVerificationCode(ctx context.Context, email, code string) error {
	if f.sendgrid != nil {
		if err := f.sendgrid.SendEmailVerificationCode(ctx, email, code); err != nil {
			slog.Warn("sendgrid failed, falling back to log notifier", "error", err)
			return f.log.SendEmailVerificationCode(ctx, email, code)
		}
		return nil
	}
	return f.log.SendEmailVerificationCode(ctx, email, code)
}

func (f *FallbackNotifier) SendEmailChangeVerification(ctx context.Context, oldEmail, newEmail, code string) error {
	if f.sendgrid != nil {
		if err := f.sendgrid.SendEmailChangeVerification(ctx, oldEmail, newEmail, code); err != nil {
			slog.Warn("sendgrid failed, falling back to log notifier", "error", err)
			return f.log.SendEmailChangeVerification(ctx, oldEmail, newEmail, code)
		}
		return nil
	}
	return f.log.SendEmailChangeVerification(ctx, oldEmail, newEmail, code)
}

func GetEmailFromEnv() string {
	email := os.Getenv("SENDGRID_FROM_EMAIL")
	if email == "" {
		return "noreply@pepinillo.app"
	}
	return email
}

func GetNameFromEnv() string {
	name := os.Getenv("SENDGRID_FROM_NAME")
	if name == "" {
		return "Pepinillo"
	}
	return name
}

func FormatEmail(email string) string {
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)
	return email
}

func IsValidEmail(email string) bool {
	email = FormatEmail(email)
	return strings.Contains(email, "@") && strings.Contains(email, ".")
}

func GenerateVerificationCode() string {
	const charset = "0123456789"
	b := make([]byte, 6)
	for i := range b {
		n, _ := randRead()
		b[i] = charset[int(n)%len(charset)]
	}
	return string(b)
}

func randRead() (byte, error) {
	b := make([]byte, 1)
	_, err := rand.Read(b)
	return b[0], err
}
