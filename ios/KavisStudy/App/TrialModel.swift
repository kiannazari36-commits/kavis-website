import SwiftUI
import Observation

/// What a button wants to do (CLAUDE.md trial rules): upload a new PDF, ask the assistant, make new quizzes/cards, share.
/// Reading old PDFs, notes, highlights, existing cards/summaries and offline use are always allowed.
enum TrialAction { case pdf, question, generate, share }

/// Trial / Premium state of the account and the "locked" message (same rules as web/src/trial/TrialProvider.tsx).
@Observable
final class TrialModel {
    var status: TrialStatus
    /// Key of the text shown in the "Premium only" dialog, nil when the dialog is closed.
    var lockedKey: String?

    init(status: TrialStatus = TrialAPI.statusNow()) {
        self.status = status
    }

    /// Reads the status from the server again (after login, on home, after an upload).
    @MainActor func refresh() async {
        if let s = await TrialAPI.getTrial() { status = s }
    }

    /// The text key explaining why the action is locked, or nil when it is allowed.
    func lockReason(for action: TrialAction) -> String? {
        if status.premium { return nil }
        if action == .share { return "pwWhyShare" }
        if status.ended { return "trialLocked" }
        if action == .pdf, status.pdfsUsed >= TrialLimits.pdfs { return "trialPdfFull" }
        if action == .question, status.questionsUsed >= TrialLimits.questions { return "trialQFull" }
        return nil
    }

    /// Runs `run` when allowed; otherwise opens the dialog.
    func perform(_ action: TrialAction, run: () -> Void) {
        if let key = lockReason(for: action) { lockedKey = key } else { run() }
    }
}
