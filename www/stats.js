const kb = 1024;
const mb = 1024 * kb;

const wk = 7;
const mo = wk * 4;
const yr = mo * 12;

(() => {

    {
        // deps per pkg
        const element = document.getElementById("chart1");
        const counts = JSON.parse(element.nextElementSibling.textContent).map((v) => v.count).sort((a, b) => a - b);
        const segments = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
        const raw = group_counts_gt(counts, segments);
        const labels = makeLabels(segments);
        makeChart(element, raw, labels);
    }
    {
        // pkg size
        const element = document.getElementById("chart2");
        const counts = JSON.parse(element.nextElementSibling.textContent).map((v) => v.count).sort((a, b) => a - b);
        const segments = [0, 1 * kb, 2 * kb, 10 * kb, 50 * kb, 100 * kb, 500 * kb, 1 * mb, 5 * mb, 10 * mb, 20 * mb];
        const raw = group_counts_gt(counts, segments);
        const labels = segments.map((v) => `≥ ${fixbytes(v)}`);
        makeChart(element, raw, labels);
    }
    {
        // releases per pkg
        const element = document.getElementById("chart3");
        const counts = JSON.parse(element.nextElementSibling.textContent).map((v) => v.count).sort((a, b) => a - b);
        const segments = [1, 2, 4, 8, 16, 32, 50, 100, 500];
        const raw = group_counts_gt(counts, segments);
        const labels = makeLabels(segments);
        makeChart(element, raw, labels);
    }
    {
        // pkgs per user
        const element = document.getElementById("chart4");
        const counts = JSON.parse(element.nextElementSibling.textContent).map((v) => v.count).sort((a, b) => a - b);
        const segments = [1, 2, 3, 6, 25, 50, 75, 100, 150, 200, 750];
        const raw = group_counts_gt(counts, segments);
        const labels = makeLabels(segments);
        makeChart(element, raw, labels);
    }
    {
        // time since first release
        doTimeChart("chart5");
        // time since latest release
        doTimeChart("chart6");
    }
})();

function doTimeChart(id) {
    const element = document.getElementById(id);
    const counts = JSON.parse(element.nextElementSibling.textContent).map((v) => `${v.time}Z`).map((v) => Date.now() - Date.parse(v)).map((v) => v / 1000 / 60 / 60 / 24 | 0);
    const segments = [0, 1 * wk, 1 * mo, 2 * mo, 3 * mo, 4 * mo, 5 * mo, 6 * mo, 1 * yr];
    const raw = group_counts_gt(counts, segments);
    const labels = ["New", "≥1 week", "≥1 month", "≥2 month", "≥3 month", "≥4 month", "≥5 month", "≥6 months", "≥1 year"];
    makeChart(element, raw, labels);
}

function group_counts_gt(counts, segments) {
    const result = new Array(segments.length).fill(0);
    for (let i = 0; i < counts.length; i++) {
        let j = 0;
        while (j < segments.length) {
            if (counts[i] < segments[j]) {
                break;
            }
            j += 1;
        }
        result[j - 1] += 1;
    }
    return result;
}

function makeLabels(segments) {
    const hasGT = (ind) => ind === segments.length - 1 || segments[ind + 1] !== segments[ind] + 1;
    return segments.map((v, i) => `${hasGT(i) ? "≥" : ""} ${v}`);
}

function makeChart(element, raw_data, labels) {
    const data = {
        labels: labels,
        datasets: [{
            data: raw_data,
            backgroundColor: ['rgba(255, 99, 132, 0.2)'],
            borderColor: ['rgb(255, 99, 132)'],
            borderWidth: 1
        }]
    };
    const config = {
        type: "bar",
        data: data,
        options: {
            maintainAspectRatio: true,
            aspectRatio: 5,
            scales: {
                y: {
                    beginAtZero: true
                }
            },
            plugins: {
                legend: {
                    display: false,
                },
            },
        },
    };
    new Chart(element, config);
}

function fixbytes(x) {
    if ((x /= 1024) < 1024) return `${Math.floor(x)}KB`;
    if ((x /= 1024) < 1024) return `${Math.floor(x)}MB`;
}
