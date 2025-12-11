import { useState } from 'react';
import { motion } from 'framer-motion';
import { Lock, User, Sparkles } from 'lucide-react';
import { apiClient } from '../api/client';

interface LoginPageProps {
    onLoginSuccess: () => void;
}

export function LoginPage({ onLoginSuccess }: LoginPageProps) {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            await apiClient.login({ username, password });
            onLoginSuccess();
        } catch (err: any) {
            setError(err.response?.data?.error || 'Login failed. Try admin/admin');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center p-4">
            <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="w-full max-w-md"
            >
                {/* Logo/Title */}
                <motion.div
                    className="text-center mb-8"
                    initial={{ scale: 0.9 }}
                    animate={{ scale: 1 }}
                    transition={{ duration: 0.5 }}
                >
                    <div className="inline-flex items-center justify-center w-20 h-20 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 mb-4 animate-float">
                        <Sparkles className="w-10 h-10" />
                    </div>
                    <h1 className="text-4xl font-bold bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
                        Dext Framework
                    </h1>
                    <p className="text-gray-400 mt-2">Controller Showcase</p>
                </motion.div>

                {/* Login Card */}
                <motion.div
                    className="glass rounded-2xl p-8 shadow-2xl"
                    whileHover={{ scale: 1.02 }}
                    transition={{ type: "spring", stiffness: 300 }}
                >
                    <h2 className="text-2xl font-semibold mb-6">Welcome Back</h2>

                    <form onSubmit={handleLogin} className="space-y-4">
                        <div>
                            <label className="block text-sm font-medium mb-2">Username</label>
                            <div className="relative">
                                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                                <input
                                    type="text"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    className="w-full pl-10 pr-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 transition-all"
                                    placeholder="admin"
                                    required
                                />
                            </div>
                        </div>

                        <div>
                            <label className="block text-sm font-medium mb-2">Password</label>
                            <div className="relative">
                                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                                <input
                                    type="password"
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="w-full pl-10 pr-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 transition-all"
                                    placeholder="admin"
                                    required
                                />
                            </div>
                        </div>

                        {error && (
                            <motion.div
                                initial={{ opacity: 0, x: -10 }}
                                animate={{ opacity: 1, x: 0 }}
                                className="p-3 bg-red-500/20 border border-red-500/50 rounded-lg text-sm text-red-200"
                            >
                                {error}
                            </motion.div>
                        )}

                        <motion.button
                            type="submit"
                            disabled={loading}
                            className="w-full py-3 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg font-semibold hover:from-purple-600 hover:to-pink-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.98 }}
                        >
                            {loading ? 'Signing in...' : 'Sign In'}
                        </motion.button>
                    </form>

                    <div className="mt-6 text-center text-sm text-gray-400">
                        <p>Default credentials: <span className="text-purple-400 font-mono">admin / admin</span></p>
                    </div>
                </motion.div>

                {/* Features */}
                <motion.div
                    className="mt-8 grid grid-cols-3 gap-4 text-center text-sm"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.3 }}
                >
                    <div className="glass rounded-lg p-3">
                        <div className="font-semibold text-purple-400">JWT Auth</div>
                        <div className="text-xs text-gray-400 mt-1">Secure</div>
                    </div>
                    <div className="glass rounded-lg p-3">
                        <div className="font-semibold text-pink-400">Validation</div>
                        <div className="text-xs text-gray-400 mt-1">Auto</div>
                    </div>
                    <div className="glass rounded-lg p-3">
                        <div className="font-semibold text-blue-400">Binding</div>
                        <div className="text-xs text-gray-400 mt-1">Smart</div>
                    </div>
                </motion.div>
            </motion.div>
        </div>
    );
}
