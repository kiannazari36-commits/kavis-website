import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { I18nProvider } from './i18n/I18nProvider';
import { ThemeProvider } from './theme/ThemeProvider';
import { ToastProvider } from './components/Toast';
import Placeholder from './pages/Placeholder';

export default function App() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <ToastProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<Placeholder name="landing" />} />
              <Route path="/login" element={<Placeholder name="login" />} />
              <Route path="/home" element={<Placeholder name="home" />} />
              <Route path="/courses" element={<Placeholder name="courses" />} />
              <Route path="/courses/:courseId" element={<Placeholder name="course" />} />
              <Route path="/reader" element={<Placeholder name="reader" />} />
              <Route path="/assistant" element={<Placeholder name="assistant" />} />
              <Route path="/quiz" element={<Placeholder name="quiz" />} />
              <Route path="/cards" element={<Placeholder name="cards" />} />
              <Route path="/plan" element={<Placeholder name="plan" />} />
              <Route path="/progress" element={<Placeholder name="progress" />} />
              <Route path="/settings" element={<Placeholder name="settings" />} />
              <Route path="/premium" element={<Placeholder name="paywall" />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </BrowserRouter>
        </ToastProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
