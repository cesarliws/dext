import { useState } from 'react';
import { motion } from 'framer-motion';
import { LogOut, Send, Search, Plus, CheckCircle, XCircle, Sparkles } from 'lucide-react';
import { apiClient } from '../api/client';

interface DashboardPageProps {
    onLogout: () => void;
}

export function DashboardPage({ onLogout }: DashboardPageProps) {
    const [activeTab, setActiveTab] = useState<'get' | 'post' | 'search'>('get');

    // GET state
    const [getName, setGetName] = useState('');
    const [getResult, setGetResult] = useState<any>(null);
    const [getLoading, setGetLoading] = useState(false);
    const [getError, setGetError] = useState('');

    // POST state
    const [postName, setPostName] = useState('');
    const [postTitle, setPostTitle] = useState('');
    const [postResult, setPostResult] = useState<any>(null);
    const [postLoading, setPostLoading] = useState(false);
    const [postError, setPostError] = useState('');

    // SEARCH state
    const [searchQuery, setSearchQuery] = useState('');
    const [searchLimit, setSearchLimit] = useState('10');
    const [searchResult, setSearchResult] = useState<any>(null);
    const [searchLoading, setSearchLoading] = useState(false);
    const [searchError, setSearchError] = useState('');

    const handleGet = async (e: React.FormEvent) => {
        e.preventDefault();
        setGetError('');
        setGetLoading(true);
        try {
            const result = await apiClient.getGreeting(getName);
            setGetResult(result);
        } catch (err: any) {
            setGetError(err.response?.data?.error || err.message);
        } finally {
            setGetLoading(false);
        }
    };

    const handlePost = async (e: React.FormEvent) => {
        e.preventDefault();
        setPostError('');
        setPostLoading(true);
        try {
            const result = await apiClient.createGreeting({ name: postName, title: postTitle });
            setPostResult(result);
        } catch (err: any) {
            setPostError(err.response?.data || err.message);
        } finally {
            setPostLoading(false);
        }
    };

    const handleSearch = async (e: React.FormEvent) => {
        e.preventDefault();
        setSearchError('');
        setSearchLoading(true);
        try {
            const result = await apiClient.searchGreeting({
                q: searchQuery,
                limit: parseInt(searchLimit)
            });
            setSearchResult(result);
        } catch (err: any) {
            setSearchError(err.response?.data?.error || err.message);
        } finally {
            setSearchLoading(false);
        }
    };

    return (
        <div className="min-h-screen p-6">
            <div className="max-w-6xl mx-auto">
                {/* Header */}
                <motion.div
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="glass rounded-2xl p-6 mb-6"
                >
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center">
                                <Sparkles className="w-6 h-6" />
                            </div>
                            <div>
                                <h1 className="text-2xl font-bold">Dext Controller Showcase</h1>
                                <p className="text-gray-400 text-sm">Demonstrating all controller features</p>
                            </div>
                        </div>
                        <motion.button
                            onClick={onLogout}
                            className="flex items-center gap-2 px-4 py-2 bg-red-500/20 hover:bg-red-500/30 border border-red-500/50 rounded-lg transition-all"
                            whileHover={{ scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                        >
                            <LogOut className="w-4 h-4" />
                            Logout
                        </motion.button>
                    </div>
                </motion.div>

                {/* Tabs */}
                <div className="glass rounded-2xl p-2 mb-6 flex gap-2">
                    {[
                        { id: 'get' as const, label: 'GET - Route Binding', icon: Send },
                        { id: 'post' as const, label: 'POST - Body Validation', icon: Plus },
                        { id: 'search' as const, label: 'GET - Query Binding', icon: Search },
                    ].map((tab) => (
                        <motion.button
                            key={tab.id}
                            onClick={() => setActiveTab(tab.id)}
                            className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium transition-all ${activeTab === tab.id
                                    ? 'bg-gradient-to-r from-purple-500 to-pink-500'
                                    : 'hover:bg-white/5'
                                }`}
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.98 }}
                        >
                            <tab.icon className="w-4 h-4" />
                            {tab.label}
                        </motion.button>
                    ))}
                </div>

                {/* Content */}
                <motion.div
                    key={activeTab}
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="glass rounded-2xl p-8"
                >
                    {activeTab === 'get' && (
                        <div>
                            <h2 className="text-xl font-semibold mb-4">GET /api/greet/:name</h2>
                            <p className="text-gray-400 mb-6">Demonstrates route parameter binding with [FromRoute]</p>

                            <form onSubmit={handleGet} className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium mb-2">Name (Route Parameter)</label>
                                    <input
                                        type="text"
                                        value={getName}
                                        onChange={(e) => setGetName(e.target.value)}
                                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                                        placeholder="Enter a name"
                                        required
                                    />
                                </div>

                                <motion.button
                                    type="submit"
                                    disabled={getLoading}
                                    className="w-full py-3 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg font-semibold disabled:opacity-50"
                                    whileHover={{ scale: 1.02 }}
                                    whileTap={{ scale: 0.98 }}
                                >
                                    {getLoading ? 'Loading...' : 'Send Request'}
                                </motion.button>
                            </form>

                            {getError && (
                                <div className="mt-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-start gap-3">
                                    <XCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                                    <div className="flex-1">
                                        <div className="font-semibold text-red-200">Error</div>
                                        <div className="text-sm text-red-300 mt-1">{getError}</div>
                                    </div>
                                </div>
                            )}

                            {getResult && (
                                <div className="mt-4 p-4 bg-green-500/20 border border-green-500/50 rounded-lg">
                                    <div className="flex items-center gap-2 mb-2">
                                        <CheckCircle className="w-5 h-5 text-green-400" />
                                        <span className="font-semibold text-green-200">Success</span>
                                    </div>
                                    <pre className="text-sm text-green-100 overflow-x-auto">
                                        {JSON.stringify(getResult, null, 2)}
                                    </pre>
                                </div>
                            )}
                        </div>
                    )}

                    {activeTab === 'post' && (
                        <div>
                            <h2 className="text-xl font-semibold mb-4">POST /api/greet/</h2>
                            <p className="text-gray-400 mb-6">Demonstrates body binding with validation ([Required], [StringLength])</p>

                            <form onSubmit={handlePost} className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium mb-2">
                                        Name <span className="text-red-400">*</span>
                                        <span className="text-xs text-gray-400 ml-2">(3-50 chars)</span>
                                    </label>
                                    <input
                                        type="text"
                                        value={postName}
                                        onChange={(e) => setPostName(e.target.value)}
                                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                                        placeholder="Enter name"
                                        required
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium mb-2">
                                        Title <span className="text-red-400">*</span>
                                    </label>
                                    <input
                                        type="text"
                                        value={postTitle}
                                        onChange={(e) => setPostTitle(e.target.value)}
                                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                                        placeholder="Enter title"
                                        required
                                    />
                                </div>

                                <motion.button
                                    type="submit"
                                    disabled={postLoading}
                                    className="w-full py-3 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg font-semibold disabled:opacity-50"
                                    whileHover={{ scale: 1.02 }}
                                    whileTap={{ scale: 0.98 }}
                                >
                                    {postLoading ? 'Creating...' : 'Create Greeting'}
                                </motion.button>
                            </form>

                            {postError && (
                                <div className="mt-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg">
                                    <div className="flex items-center gap-2 mb-2">
                                        <XCircle className="w-5 h-5 text-red-400" />
                                        <span className="font-semibold text-red-200">Validation Error</span>
                                    </div>
                                    <pre className="text-sm text-red-100 overflow-x-auto">
                                        {typeof postError === 'string' ? postError : JSON.stringify(postError, null, 2)}
                                    </pre>
                                </div>
                            )}

                            {postResult && (
                                <div className="mt-4 p-4 bg-green-500/20 border border-green-500/50 rounded-lg">
                                    <div className="flex items-center gap-2 mb-2">
                                        <CheckCircle className="w-5 h-5 text-green-400" />
                                        <span className="font-semibold text-green-200">Created (201)</span>
                                    </div>
                                    <pre className="text-sm text-green-100 overflow-x-auto">
                                        {JSON.stringify(postResult, null, 2)}
                                    </pre>
                                </div>
                            )}
                        </div>
                    )}

                    {activeTab === 'search' && (
                        <div>
                            <h2 className="text-xl font-semibold mb-4">GET /api/greet/search</h2>
                            <p className="text-gray-400 mb-6">Demonstrates query parameter binding with custom names ([FromQuery])</p>

                            <form onSubmit={handleSearch} className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium mb-2">
                                        Search Query <span className="text-xs text-gray-400">(mapped to 'q')</span>
                                    </label>
                                    <input
                                        type="text"
                                        value={searchQuery}
                                        onChange={(e) => setSearchQuery(e.target.value)}
                                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                                        placeholder="Search term"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium mb-2">Limit</label>
                                    <input
                                        type="number"
                                        value={searchLimit}
                                        onChange={(e) => setSearchLimit(e.target.value)}
                                        className="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                                        placeholder="10"
                                    />
                                </div>

                                <motion.button
                                    type="submit"
                                    disabled={searchLoading}
                                    className="w-full py-3 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg font-semibold disabled:opacity-50"
                                    whileHover={{ scale: 1.02 }}
                                    whileTap={{ scale: 0.98 }}
                                >
                                    {searchLoading ? 'Searching...' : 'Search'}
                                </motion.button>
                            </form>

                            {searchError && (
                                <div className="mt-4 p-4 bg-red-500/20 border border-red-500/50 rounded-lg flex items-start gap-3">
                                    <XCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                                    <div className="flex-1">
                                        <div className="font-semibold text-red-200">Error</div>
                                        <div className="text-sm text-red-300 mt-1">{searchError}</div>
                                    </div>
                                </div>
                            )}

                            {searchResult && (
                                <div className="mt-4 p-4 bg-green-500/20 border border-green-500/50 rounded-lg">
                                    <div className="flex items-center gap-2 mb-2">
                                        <CheckCircle className="w-5 h-5 text-green-400" />
                                        <span className="font-semibold text-green-200">Results</span>
                                    </div>
                                    <pre className="text-sm text-green-100 overflow-x-auto">
                                        {JSON.stringify(searchResult, null, 2)}
                                    </pre>
                                </div>
                            )}
                        </div>
                    )}
                </motion.div>

                {/* Features Grid */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2 }}
                    className="mt-6 grid grid-cols-1 md:grid-cols-3 gap-4"
                >
                    {[
                        { title: 'Smart Binding', desc: 'Body, Query, Route, Services', color: 'from-purple-500 to-pink-500' },
                        { title: 'Auto Validation', desc: '[Required], [StringLength]', color: 'from-blue-500 to-cyan-500' },
                        { title: 'JWT Security', desc: '[SwaggerAuthorize] enforcement', color: 'from-green-500 to-emerald-500' },
                    ].map((feature, i) => (
                        <div key={i} className="glass rounded-xl p-4">
                            <div className={`w-10 h-10 rounded-lg bg-gradient-to-br ${feature.color} flex items-center justify-center mb-3`}>
                                <Sparkles className="w-5 h-5" />
                            </div>
                            <h3 className="font-semibold mb-1">{feature.title}</h3>
                            <p className="text-sm text-gray-400">{feature.desc}</p>
                        </div>
                    ))}
                </motion.div>
            </div>
        </div>
    );
}
