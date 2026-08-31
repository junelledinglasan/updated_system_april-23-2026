import os
from django.core.mail import send_mail
from django.conf import settings


def send_email(to_email, subject, html_body):
    """Send email via Gmail SMTP."""
    if not to_email:
        return False
    try:
        send_mail(
            subject=subject,
            message="",
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[to_email],
            html_message=html_body,
            fail_silently=False,
        )
        return True
    except Exception as e:
        print(f"[EMAIL ERROR] Failed to send to {to_email}: {e}")
        return False


# ── Template helpers ──────────────────────────────────────────────────────────

def _base(content):
    return f"""
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body {{ font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 0; }}
  .wrap {{ max-width: 580px; margin: 32px auto; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }}
  .header {{ background: #1b5e20; padding: 28px 32px; text-align: center; }}
  .header img {{ height: 40px; }}
  .header h1 {{ color: #fff; margin: 8px 0 0; font-size: 22px; letter-spacing: 0.3px; }}
  .header p {{ color: #a5d6a7; margin: 4px 0 0; font-size: 13px; }}
  .body {{ padding: 28px 32px; }}
  .body p {{ color: #444; font-size: 14px; line-height: 1.7; margin: 0 0 14px; }}
  .info-box {{ background: #f1f8e9; border-left: 4px solid #2e7d32; border-radius: 6px; padding: 16px 20px; margin: 18px 0; }}
  .info-row {{ display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #e8f5e9; font-size: 13px; }}
  .info-row:last-child {{ border-bottom: none; }}
  .info-label {{ color: #666; font-weight: 600; }}
  .info-value {{ color: #1b5e20; font-weight: 700; }}
  .alert-box {{ background: #fff8e1; border-left: 4px solid #f9a825; border-radius: 6px; padding: 14px 20px; margin: 18px 0; font-size: 13px; color: #5d4037; }}
  .footer {{ background: #f9fbe7; padding: 18px 32px; text-align: center; font-size: 11px; color: #aaa; border-top: 1px solid #e8f0e9; }}
</style>
</head>
<body>
<div class="wrap">
  <div class="header">
    <h1>LEAF MPC</h1>
    <p>Leaf Multi-Purpose Cooperative · Lucban, Quezon</p>
  </div>
  <div class="body">
    {content}
  </div>
  <div class="footer">
    This is an automated message from LEAF MPC System. Please do not reply to this email.<br>
    Lucban, Quezon, Philippines
  </div>
</div>
</body>
</html>
"""


# ══════════════════════════════════════════════════════════════════
#  MEMBERSHIP
# ══════════════════════════════════════════════════════════════════

def send_member_approved_email(email, fullname, member_id, username, plain_password, membership_date):
    """Send email when an ONLINE APPLICATION is converted to official member."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Congratulations! You are now an official member of <strong>LEAF Multi-Purpose Cooperative</strong>.
    Your membership has been approved and your account is ready to use.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Full Name</span><span class="info-value">{fullname}</span></div>
      <div class="info-row"><span class="info-label">Username</span><span class="info-value">{username}</span></div>
      <div class="info-row"><span class="info-label">Password</span><span class="info-value">{plain_password}</span></div>
      <div class="info-row"><span class="info-label">Membership Date</span><span class="info-value">{membership_date}</span></div>
    </div>

    <div class="alert-box">
      ⚠️ <strong>Important:</strong> Please keep your login credentials safe and confidential.
      Change your password after your first login.
    </div>

    <p>You may now log in to the LEAF MPC system to view your membership details,
    apply for loans, and track your savings.</p>
    <p>Welcome to the LEAF MPC family!</p>
    """
    return send_email(
        email,
        "Welcome to LEAF MPC — You are now an Official Member!",
        _base(content)
    )


def send_member_registered_email(email, fullname, member_id, username, plain_password, membership_date):
    """Send email when admin registers a member F2F (walk-in) — credentials only."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Congratulations! You are now an official member of <strong>LEAF Multi-Purpose Cooperative</strong>.
    Your membership account has been created and is ready to use.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Full Name</span><span class="info-value">{fullname}</span></div>
      <div class="info-row"><span class="info-label">Username</span><span class="info-value">{username}</span></div>
      <div class="info-row"><span class="info-label">Password</span><span class="info-value">{plain_password}</span></div>
      <div class="info-row"><span class="info-label">Membership Date</span><span class="info-value">{membership_date}</span></div>
    </div>

    <div class="alert-box">
      <strong>Important:</strong> Please keep your login credentials safe and confidential.
      Change your password after your first login for security.
    </div>

    <p>You may now log in to the LEAF MPC member portal to view your membership details,
    apply for loans, and track your savings.</p>
    <p>Welcome to the LEAF MPC family!</p>
    """
    return send_email(
        email,
        "Welcome to LEAF MPC — Your Membership Account is Ready",
        _base(content)
    )


def send_application_approved_email(email, fullname, app_id):
    """Send email when online application is approved — with requirements to bring to office."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Your LEAF MPC membership application (<strong>{app_id}</strong>) has been
    <strong style="color:#1b5e20;">APPROVED</strong>!</p>

    <p>Please visit the LEAF MPC office to complete your membership registration.</p>

    <div class="info-box" style="background:#e3f2fd;border-left-color:#1565c0;">
      <div style="font-weight:700;color:#1565c0;margin-bottom:12px;font-size:14px;">
        Requirements to Bring:
      </div>
      <div class="info-row">
        <span class="info-label">ID Picture</span>
        <span class="info-value">2 pieces 2x2, white background</span>
      </div>
      <div class="info-row">
        <span class="info-label">Birth Certificate</span>
        <span class="info-value">PSA copy (photocopy accepted)</span>
      </div>
      <div class="info-row">
        <span class="info-label">Marriage Certificate</span>
        <span class="info-value">If married — optional</span>
      </div>
      <div class="info-row">
        <span class="info-label">Valid ID</span>
        <span class="info-value">Any government-issued ID</span>
      </div>
      <div class="info-row">
        <span class="info-label">Share Capital</span>
        <span class="info-value">Minimum ₱4,000 initial payment</span>
      </div>
    </div>

    <div class="alert-box">
      <strong>Office Hours:</strong> Monday – Friday, 8:00 AM – 5:00 PM<br>
      <strong>Location:</strong> LEAF MPC Office, Lucban, Quezon
    </div>

    <p>Please bring all requirements to avoid delays in processing.
    We look forward to welcoming you as an official LEAF MPC member!</p>
    """
    return send_email(
        email,
        f"Membership Application Approved — {app_id} | Please Visit the Office",
        _base(content)
    )


def send_application_rejected_email(email, fullname, app_id, reject_reason):
    """Send email when an online membership application is rejected."""
    content = f"""
    <h2 style="color:#c62828;">Membership Application Update</h2>
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Thank you for your interest in becoming a LEAF MPC member. After careful review, we regret to inform you
    that your application has <strong>not been approved</strong> at this time.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Application ID</span><span class="info-value">{app_id}</span></div>
    </div>

    <div class="alert-box">
      <strong>Reason:</strong> {reject_reason or 'Please visit the LEAF MPC office for more details.'}
    </div>

    <p>You are welcome to re-apply once the noted concerns have been addressed, or visit our office for assistance.</p>
    """
    return send_email(
        email,
        f"LEAF MPC — Membership Application Update ({app_id})",
        _base(content)
    )


# ══════════════════════════════════════════════════════════════════
#  LOANS
# ══════════════════════════════════════════════════════════════════

def send_loan_approved_email(email, fullname, member_id, loan_id, loan_type, amount, monthly_due, term_months, next_due_date):
    """Send email when loan is approved."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Great news! Your loan application has been <strong>approved</strong> by LEAF MPC.
    Please review your loan details below.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">Loan Type</span><span class="info-value">{loan_type}</span></div>
      <div class="info-row"><span class="info-label">Loan Amount</span><span class="info-value">₱{float(amount):,.2f}</span></div>
      <div class="info-row"><span class="info-label">Monthly Due</span><span class="info-value">₱{float(monthly_due):,.2f}</span></div>
      <div class="info-row"><span class="info-label">Term</span><span class="info-value">{term_months} months</span></div>
      <div class="info-row"><span class="info-label">First Due Date</span><span class="info-value">{next_due_date}</span></div>
    </div>

    <div class="alert-box">
      <strong>Reminder:</strong> Please pay your monthly due of
      <strong>₱{float(monthly_due):,.2f}</strong> on or before <strong>{next_due_date}</strong>
      to avoid penalties.
    </div>

    <p>Please visit the LEAF MPC office to sign the necessary loan documents.
    You can track your loan status and payment history in the LEAF MPC system.</p>
    """
    return send_email(
        email,
        f"Loan Approved — {loan_id} · ₱{float(amount):,.2f}",
        _base(content)
    )


def send_loan_declined_email(email, fullname, member_id, loan_id, loan_type, amount, decline_reason):
    """Send email when a loan application is declined."""
    content = f"""
    <h2 style="color:#c62828;">Loan Application Update</h2>
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>We regret to inform you that your loan application has <strong>not been approved</strong> at this time.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">Loan Type</span><span class="info-value">{loan_type}</span></div>
      <div class="info-row"><span class="info-label">Amount Requested</span><span class="info-value">₱{float(amount):,.2f}</span></div>
    </div>

    <div class="alert-box">
      <strong>Reason:</strong> {decline_reason or 'Please visit the LEAF MPC office for more details.'}
    </div>

    <p>You may re-apply once the noted concerns have been addressed, or visit our office for assistance.</p>
    """
    return send_email(
        email,
        f"LEAF MPC — Loan Application Update ({loan_id})",
        _base(content)
    )


def send_due_date_reminder_email(email, fullname, member_id, loan_id, loan_type, monthly_due, due_date, balance):
    """Send email 3 days before payment due date."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>This is a friendly reminder that your loan payment is due in <strong>3 days</strong>.
    Please make sure to pay on time to avoid penalties.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">Loan Type</span><span class="info-value">{loan_type}</span></div>
      <div class="info-row"><span class="info-label">Amount Due</span><span class="info-value" style="color:#c62828;font-size:16px;">₱{float(monthly_due):,.2f}</span></div>
      <div class="info-row"><span class="info-label">Due Date</span><span class="info-value" style="color:#e65100;">⚠ {due_date}</span></div>
      <div class="info-row"><span class="info-label">Remaining Balance</span><span class="info-value">₱{float(balance):,.2f}</span></div>
    </div>

    <div class="alert-box">
      💳 <strong>How to pay:</strong> Visit the LEAF MPC office to pay your monthly due.
      Bring your Member ID for reference.
    </div>

    <p>If you have already paid, please disregard this message.
    Thank you for being a responsible member of LEAF MPC!</p>
    """
    return send_email(
        email,
        f"⚠️ Payment Reminder — {loan_id} due on {due_date}",
        _base(content)
    )


# ══════════════════════════════════════════════════════════════════
#  GCASH PAYMENTS
# ══════════════════════════════════════════════════════════════════

def send_gcash_verified_email(email, fullname, member_id, loan_id, reference_number, amount, new_balance):
    """Send email when GCash payment is verified by admin."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Good news! Your GCash payment has been <strong>verified and recorded</strong> by LEAF MPC.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">GCash Reference No.</span><span class="info-value">{reference_number}</span></div>
      <div class="info-row"><span class="info-label">Amount Paid</span><span class="info-value" style="color:#2e7d32;font-size:16px;">₱{float(amount):,.2f}</span></div>
      <div class="info-row"><span class="info-label">Remaining Balance</span><span class="info-value">₱{float(new_balance):,.2f}</span></div>
    </div>

    {"<div class='alert-box'>🎉 <strong>Congratulations!</strong> Your loan is now fully paid!</div>" if float(new_balance) == 0 else ""}

    <p>Your payment has been recorded in the LEAF MPC system. You can view your updated
    payment history by logging in to the LEAF MPC member portal.</p>
    <p>Thank you for your payment!</p>
    """
    return send_email(
        email,
        f"✅ GCash Payment Verified — {loan_id} · Ref: {reference_number}",
        _base(content)
    )


def send_gcash_rejected_email(email, fullname, member_id, loan_id, reference_number, amount, reject_reason):
    """Send email when GCash payment is rejected by admin."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>We were unable to verify your GCash payment for loan <strong>{loan_id}</strong>.
    Please review the details below and resubmit with the correct information.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">Reference No. Submitted</span><span class="info-value">{reference_number}</span></div>
      <div class="info-row"><span class="info-label">Amount</span><span class="info-value">₱{float(amount):,.2f}</span></div>
      <div class="info-row"><span class="info-label">Status</span><span class="info-value" style="color:#c62828;">❌ Not Verified</span></div>
    </div>

    <div class="alert-box">
      ⚠️ <strong>Reason:</strong> {reject_reason}
    </div>

    <p>To resubmit your payment:</p>
    <ol style="color:#444;font-size:14px;line-height:2;">
      <li>Log in to the LEAF MPC member portal</li>
      <li>Go to <strong>My Loans</strong></li>
      <li>Click <strong>Pay via GCash</strong> on your active loan</li>
      <li>Enter the correct GCash reference number</li>
    </ol>

    <p>If you believe this is an error, please contact the LEAF MPC office directly.</p>
    """
    return send_email(
        email,
        f"❌ GCash Payment Not Verified — {loan_id} · Ref: {reference_number}",
        _base(content)
    )


# ══════════════════════════════════════════════════════════════════
#  LOAN — APPROVED, WAITING FOR RELEASE (bagong 2-step na flow)
# ══════════════════════════════════════════════════════════════════

def send_loan_approved_pending_release_email(email, fullname, member_id, loan_id, loan_type, amount):
    """Send email when loan is Approved — pero hindi pa na-release
    ang pera. Kailangan pang pumunta sa opisina para kunin."""
    content = f"""
    <p>Dear <strong>{fullname}</strong>,</p>
    <p>Great news! Your loan application has been <strong>approved</strong> by LEAF MPC.
    Please visit the LEAF MPC office to claim your loan proceeds and sign the necessary documents.</p>

    <div class="info-box">
      <div class="info-row"><span class="info-label">Member ID</span><span class="info-value">{member_id}</span></div>
      <div class="info-row"><span class="info-label">Loan ID</span><span class="info-value">{loan_id}</span></div>
      <div class="info-row"><span class="info-label">Loan Type</span><span class="info-value">{loan_type}</span></div>
      <div class="info-row"><span class="info-label">Loan Amount</span><span class="info-value">₱{float(amount):,.2f}</span></div>
    </div>

    <div class="alert-box">
      <strong>Next Step:</strong> Please visit the LEAF MPC office during office hours
      (Mon–Fri, 8:00 AM – 5:00 PM) to claim your loan proceeds. Your monthly due date
      and repayment schedule will be confirmed once your loan is released.
    </div>

    <p>Please bring a valid ID for verification. We look forward to seeing you soon!</p>
    """
    return send_email(
        email,
        f"Loan Approved — {loan_id} · Please Visit the Office to Claim",
        _base(content)
    )