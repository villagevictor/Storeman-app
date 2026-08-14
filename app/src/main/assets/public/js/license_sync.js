document.addEventListener("DOMContentLoaded", () => {
    // 1. Check 30-Day Trial
    let installDate = localStorage.getItem("app_install_date");
    if (!installDate) {
        installDate = new Date().toISOString();
        localStorage.setItem("app_install_date", installDate);
    }

    const startDate = new Date(installDate);
    const currentDate = new Date();
    const diffDays = Math.ceil((currentDate - startDate) / (1000 * 60 * 60 * 24));

    // የጊዜ ገደብ ማሳወቂያ በገፁ አናት ላይ ማሳየት
    const banner = document.createElement("div");
    banner.style.cssText = "background: #111827; color: #38bdf8; text-align: center; padding: 8px; font-size: 12px; font-weight: bold;";
    banner.innerText = `Storeman Cloud Connected | Trial: Day ${diffDays} of 30`;
    document.body.insertBefore(banner, document.body.firstChild);

    if (diffDays > 30 && !localStorage.getItem("is_subscribed")) {
        document.body.innerHTML = `
            <div style="text-align:center; padding: 50px; font-family: sans-serif;">
                <h1 style="color: red;">የሙከራ ጊዜው አልቋል!</h1>
                <p>የ 30 ቀን ነጻ የሙከራ ጊዜዎ አብቅቷል። እባክዎን አገልግሎቱን ለመቀጠል ክፍያ ይፈጽሙ።</p>
            </div>
        `;
    }
});
