import { lazy, Suspense } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { I18nProvider } from './i18n/I18nProvider';
import { ThemeProvider } from './theme/ThemeProvider';
import { ToastProvider } from './components/Toast';
import { SettingsProvider } from './settings/SettingsProvider';
import PrefsSync from './settings/PrefsSync';
import { TrialProvider } from './trial/TrialProvider';
import AppShell from './components/AppShell';
import Landing from './pages/Landing';
import Login from './pages/Login';
const Home = lazy(() => import('./pages/Home'));
const Courses = lazy(() => import('./pages/Courses'));
const CourseFolder = lazy(() => import('./pages/CourseFolder'));
const Reader = lazy(() => import('./pages/Reader'));
const Assistant = lazy(() => import('./pages/Assistant'));
const Quiz = lazy(() => import('./pages/Quiz'));
const Summary = lazy(() => import('./pages/Summary'));
const Cards = lazy(() => import('./pages/Cards'));
const Plan = lazy(() => import('./pages/Plan'));
const Progress = lazy(() => import('./pages/Progress'));
const Settings = lazy(() => import('./pages/Settings'));
const Notifications = lazy(() => import('./pages/Notifications'));
const Schedule = lazy(() => import('./pages/Schedule'));
const Upload = lazy(() => import('./pages/Upload'));
const Record = lazy(() => import('./pages/Record'));
const Recording = lazy(() => import('./pages/Recording'));
const Samples = lazy(() => import('./pages/Samples'));
const Admin = lazy(() => import('./pages/Admin'));
const Welcome = lazy(() => import('./pages/Welcome'));
const Paywall = lazy(() => import('./pages/Paywall'));
const DeviceLimit = lazy(() => import('./pages/DeviceLimit'));
const ShareLink = lazy(() => import('./pages/ShareLink'));
const Legal = lazy(() => import('./pages/Legal'));
const Help = lazy(() => import('./pages/Help'));
const Exam = lazy(() => import('./pages/Exam'));
const Review = lazy(() => import('./pages/Review'));

export default function App() {
  return (
    <ThemeProvider>
      <I18nProvider>
        <SettingsProvider>
          <PrefsSync />
          <ToastProvider>
            <BrowserRouter>
              <TrialProvider>
                {/* Pages other than the first two load when they are opened (smaller first download). */}
                <Suspense fallback={null}>
                <Routes>
                  <Route path="/" element={<Landing />} />
                  <Route path="/login" element={<Login />} />
                  <Route path="/welcome" element={<Welcome />} />
                  {/* Pages with the sidebar */}
                  <Route element={<AppShell />}>
                    <Route path="/home" element={<Home />} />
                    <Route path="/courses" element={<Courses />} />
                    <Route path="/courses/:courseId" element={<CourseFolder />} />
                    <Route path="/reader" element={<Reader />} />
                    <Route path="/assistant" element={<Assistant />} />
                    <Route path="/quiz" element={<Quiz />} />
                    <Route path="/summary" element={<Summary />} />
                    <Route path="/exam" element={<Exam />} />
                    <Route path="/review" element={<Review />} />
                    <Route path="/cards" element={<Cards />} />
                    <Route path="/plan" element={<Plan />} />
                    <Route path="/progress" element={<Progress />} />
                    <Route path="/settings" element={<Settings />} />
                    <Route path="/notifications" element={<Notifications />} />
                    <Route path="/schedule" element={<Schedule />} />
                    <Route path="/upload" element={<Upload />} />
                    <Route path="/record" element={<Record />} />
                    <Route path="/recording" element={<Recording />} />
                    <Route path="/samples" element={<Samples />} />
                    <Route path="/help" element={<Help />} />
                    <Route path="/admin" element={<Admin />} />
                  </Route>
                  <Route path="/premium" element={<Paywall />} />
                  <Route path="/devices" element={<DeviceLimit />} />
                  <Route path="/terms" element={<Legal kind="terms" />} />
                  <Route path="/privacy" element={<Legal kind="privacy" />} />
                  <Route path="/s/:shareId" element={<ShareLink />} />
                  <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
                </Suspense>
              </TrialProvider>
            </BrowserRouter>
          </ToastProvider>
        </SettingsProvider>
      </I18nProvider>
    </ThemeProvider>
  );
}
