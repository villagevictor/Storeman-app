document.addEventListener("DOMContentLoaded", () => {
    // 1. የ 30 ቀን Trial ቁጥጥር
    let installDate = localStorage.getItem("app_install_date");
    if (!installDate) {
        installDate = new Date().toISOString();
        localStorage.setItem("app_install_date", installDate);
    }

    const startDate = new Date(installDate);
    const currentDate = new Date();
    const diffDays = Math.ceil((currentDate - startDate) / (1000 * 60 * 60 * 24));

    // 2. Banner ማሳያ Create ማድረግ
    const banner = document.createElement("div");
    banner.style.cssText = "background: #0f172a; color: #38bdf8; text-align: center; padding: 10px; font-size: 13px; font-weight: bold; border-bottom: 2px solid #0284c7; width: 100%; position: sticky; top: 0; z-index: 9999;";
    banner.innerText = `⚡ Storeman Cloud Connected | Trial: Day ${diffDays} of 30`;
    document.body.insertBefore(banner, document.body.firstChild);

    // 3. የሙከራ ጊዜው ሲያልቅ አፑን መቆለፍ
    if (diffDays > 30 && !localStorage.getItem("is_subscribed")) {
        document.body.innerHTML = `
            <div style="text-align:center; padding: 50px; font-family: sans-serif; background-color: #ffffff; height: 100vh;">
                <h1 style="color: #dc2626;">የሙከራ ጊዜው አልቋል!</h1>
                <p style="color: #4b5563;">የ 30 ቀን ነጻ የሙከራ ጊዜዎ አብቅቷል። እባክዎን አገልግሎቱን ለመቀጠል ክፍያ ይፈጽሙ።</p>
                <p><b>የድጋፍ ስልክ:</b> +251900000000</p>
            </div>
        `;
    }
});
