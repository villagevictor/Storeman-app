// Supabase & Licensing Management System
const SUPABASE_URL = "https://cfnrbgfczqfpmdjzzbia.supabase.co";
const SUPABASE_KEY = "sb_publishable_AN3kSG6xIx38ThIMg4o28w_u6kPIrn2";

// 1. Check Trial Period (30 Days Limit)
function checkLicense() {
    let installDate = localStorage.getItem("app_install_date");
    if (!installDate) {
        installDate = new Date().toISOString();
        localStorage.setItem("app_install_date", installDate);
    }

    const startDate = new Date(installDate);
    const currentDate = new Date();
    const diffDays = Math.ceil((currentDate - startDate) / (1000 * 60 * 60 * 24));

    if (diffDays > 30 && !localStorage.getItem("is_subscribed")) {
        document.body.innerHTML = `
            <div style="text-align:center; padding: 50px; font-family: sans-serif;">
                <h1 style="color: red;">የሙከራ ጊዜው አልቋል!</h1>
                <p>የ 30 ቀን ነጻ የሙከራ ጊዜዎ አብቅቷል። እባክዎን አገልግሎቱን ለመቀጠል ክፍያ ይፈጽሙ።</p>
                <p><b>ተገናኝ:</b> +251900000000</p>
            </div>
        `;
        throw new Error("License Expired");
    }
}

// 2. Initialize Core Setup
document.addEventListener("DOMContentLoaded", () => {
    checkLicense();
    console.log("Storeman Security & Trial Active");
});
