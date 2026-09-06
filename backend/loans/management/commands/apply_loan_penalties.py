# backend/loans/management/commands/apply_loan_penalties.py
#
# ── BAGO: 2% penalty kada buwang naliban sa due date. Ang command na
# 'to ang dapat patakbuhin ARAW-ARAW via cron (o Celery beat, kung meron
# kayong ganoon) — hinahanap nito ang lahat ng Active/Overdue loans,
# tinitignan kung lumagpas na sila sa "next_due_date", at kung gayon,
# inilalagay ang 2% na penalty (base sa Monthly Amortization) sa
# "balance" nila — isang beses lang kada BAGONG buwan na naliban, hindi
# paulit-ulit kung paulit-ulit patakbuhin ang command sa parehong araw.
#
# Paano patakbuhin nang manu-mano (para sa testing):
#   python manage.py apply_loan_penalties
#
# Paano i-set up bilang araw-araw na cron job (Linux):
#   0 1 * * *  cd /path/to/backend && /path/to/venv/bin/python manage.py apply_loan_penalties
#   (tumatakbo ito tuwing 1:00 AM araw-araw)

from django.core.management.base import BaseCommand
from loans.models import Loan


class Command(BaseCommand):
    help = 'Mag-apply ng 2% penalty sa lahat ng Active/Overdue loans na lumagpas na sa due date.'

    def handle(self, *args, **options):
        loans = Loan.objects.filter(status__in=['Active', 'Overdue'])
        total_applied = 0
        total_penalty = 0

        for loan in loans:
            penalty = loan.apply_overdue_penalty()
            if penalty > 0:
                total_applied += 1
                total_penalty += penalty
                self.stdout.write(self.style.WARNING(
                    f'  {loan.loan_id} ({loan.member.fullname}) — dinagdagan ng ₱{penalty} na penalty. '
                    f'Bagong balance: ₱{loan.balance}'
                ))

        self.stdout.write(self.style.SUCCESS(
            f'Tapos na. {total_applied} loan(s) ang nadagdagan ng penalty, '
            f'kabuuang ₱{total_penalty} na idinagdag.'
        ))