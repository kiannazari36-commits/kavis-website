import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { I18nProvider } from './i18n/I18nProvider';
import { ThemeProvider } from './theme/ThemeProvider';
import { ToastProvider } from './components/Toast';
import AppShell from './components/AppShell';
import Placeholder from './pages/Placeholder';
import Landing from './pages/Landing';
import Login from './pages/Login';
import Home from './pages/Home';
import Courses from './pages/Courses';
import CourseFolder from './pages/CourseFolder';
import Reader from './pages/Reader';
import Assistant from './pages/Assistant';
import Quiz from './pages/Quiz';
import Cards from './pages/Cards';

export default function App() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <ToastProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<Landing />} />
              <Route path="/login" element={<Login />} />
              {/* Pages with the sidebar */}
              <Route element={<AppShell />}>
                <Route path="/home" element={<Home />} />
                <Route path="/courses" element={<Courses />} />
                <Route path="/courses/:courseId" element={<CourseFolder />} />
                <Route path="/reader" element={<Reader />} />
                <Route path="/assistant" element={<Assistant />} />
                <Route path="/quiz" element={<Quiz />} />
                <Route path="/cards" element={<Cards />} />
                <Route path="/plan" element={<Placeholder name="plan" />} />
                <Route path="/progress" element={<Placeholder name="progress" />} />
                <Route path="/settings" element={<Placeholder name="settings" />} />
              </Route>
              <Route path="/premium" element={<Placeholder name="paywall" />} />
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </BrowserRouter>
        </ToastProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
