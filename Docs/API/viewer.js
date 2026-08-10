// Client-Side Logic for Dext Documentation
document.addEventListener('DOMContentLoaded', () => {
    
    // 1. Theme Toggling
    const themeToggle = document.getElementById('themeToggle');
    const storedTheme = localStorage.getItem('dext-theme') || 'dark';
    document.documentElement.setAttribute('data-theme', storedTheme);

    themeToggle.addEventListener('click', () => {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('dext-theme', newTheme);
    });

    // 2. Load TOC dynamically from window.DEXT_TOC
    const navList = document.getElementById('navList');
    const searchInput = document.getElementById('searchInput');
    const currentFile = window.location.pathname.split('/').pop() || 'index.html';
    const items = window.DEXT_TOC || [];

    if (navList) {
        navList.innerHTML = '';
        items.forEach(item => {
            const a = document.createElement('a');
            a.href = item.file;
            a.className = 'nav-item';
            if (item.file === currentFile) {
                a.classList.add('active');
            }
            a.textContent = item.name;
            navList.appendChild(a);
        });

        // Index page unit list container if present
        const indexListGroup = document.getElementById('indexUnitList');
        if (indexListGroup) {
            indexListGroup.innerHTML = navList.innerHTML;
        }
    }

    // 3. Search Functionality
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const term = e.target.value.toLowerCase();
            const navItems = document.querySelectorAll('.nav-item');
            navItems.forEach(item => {
                const text = item.textContent.toLowerCase();
                if (text.includes(term)) {
                    item.style.display = 'block';
                } else {
                    item.style.display = 'none';
                }
            });
        });
    }

    // 4. Initialize Mermaid Manually to fix SVG sizing
    mermaid.initialize({ 
        startOnLoad: false, 
        "class": { useMaxWidth: false },
        theme: document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'default' 
    });

    mermaid.run().then(() => {
        document.querySelectorAll('.mermaid-container svg').forEach(svg => {
             const viewBox = svg.getAttribute("viewBox");
             if (viewBox) {
                 const parts = viewBox.split(" ");
                 const width = parts[2];
                 const height = parts[3];
                 svg.style.width = width + "px";
                 svg.style.height = height + "px";
             }
             svg.style.maxWidth = "none";
             svg.removeAttribute("width");
        });
        
        document.querySelectorAll('.mermaid').forEach(el => el.style.visibility = 'visible');
    });
});