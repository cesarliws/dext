import axios from 'axios';

const API_BASE_URL = 'http://localhost:8080';

export interface LoginRequest {
    username: string;
    password: string;
}

export interface LoginResponse {
    token: string;
    username: string;
}

export interface GreetingRequest {
    name: string;
    title: string;
}

export interface GreetingFilter {
    q?: string;
    limit?: number;
}

class ApiClient {
    private token: string | null = null;

    constructor() {
        // Load token from localStorage
        this.token = localStorage.getItem('dext_token');
    }

    setToken(token: string) {
        this.token = token;
        localStorage.setItem('dext_token', token);
    }

    clearToken() {
        this.token = null;
        localStorage.removeItem('dext_token');
    }

    getAuthHeaders() {
        return this.token ? { Authorization: `Bearer ${this.token}` } : {};
    }

    async login(credentials: LoginRequest): Promise<LoginResponse> {
        const response = await axios.post<LoginResponse>(
            `${API_BASE_URL}/api/auth/login`,
            credentials
        );
        this.setToken(response.data.token);
        return response.data;
    }

    async getGreeting(name: string): Promise<{ message: string }> {
        const response = await axios.get(
            `${API_BASE_URL}/api/greet/${name}`,
            { headers: this.getAuthHeaders() }
        );
        return response.data;
    }

    async createGreeting(request: GreetingRequest): Promise<any> {
        const response = await axios.post(
            `${API_BASE_URL}/api/greet/`,
            request,
            { headers: this.getAuthHeaders() }
        );
        return response.data;
    }

    async searchGreeting(filter: GreetingFilter): Promise<any> {
        const params = new URLSearchParams();
        if (filter.q) params.append('q', filter.q);
        if (filter.limit) params.append('limit', filter.limit.toString());

        const response = await axios.get(
            `${API_BASE_URL}/api/greet/search?${params.toString()}`,
            { headers: this.getAuthHeaders() }
        );
        return response.data;
    }
}

export const apiClient = new ApiClient();
