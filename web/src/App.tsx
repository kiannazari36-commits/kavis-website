import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { I18nProvider } from './i18n/I18nProvider';
import { ThemeProvider } from './theme/ThemeProvider';
import { ToastProvider } from './components/Toast';
import { SettingsProvider } from './settings/SettingsProvider';
import { TrialProvider } from './trial/TrialProvider';
import AppShell from './components/AppShell';
import Landing from './pages/Landing';
import Login from './pages/Login';
import Home from './pages/Home';
import Courses from './pages/Courses';
import CourseFolder from './pages/CourseFolder';
import Reader from './pages/Reader';
import Assistant from './pages/Assistant';
import Quiz from './pages/Quiz';
import Cards from './pages/Cards';
import Plan from './pages/Plan';
import Progress from './pages/Progress';
import Settings from './pages/Settings';
import Paywall from './pages/Paywall';
import DeviceLimit from './pages/DeviceLimit';

export default function App() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <SettingsProvider>
          <ToastProvider>
            <BrowserRouter>
              <TrialProvider>
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
                    <Route path="/plan" element={<Plan />} />
                    <Route path="/progress" element={<Progress />} />
                    <Route path="/settings" element={<Settings />} />
                  </Route>
                  <Route path="/premium" element={<Paywall />} />
                  <Route path="/devices" element={<DeviceLimit />} />
                  <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
              </TrialProvider>
            </BrowserRouter>
          </ToastProvider>
        </SettingsProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
