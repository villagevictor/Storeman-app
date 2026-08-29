(function () {
  "use strict";

  /*
   * STOREMAN AUTOMATIC STOCK ENGINE
   *
   * Formula:
   *
   * Current Stock =
   * Initial Stock + Total Stock IN - Total Stock OUT
   *
   * This module does NOT replace the existing ERP renderer.
   * It calculates stock safely from the existing localStorage
   * products_store and transactions_store structures.
   */

  function read(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
    } catch (_) {
      return fallback;
    }
  }

  function number(v) {
    const n = Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  function idOf(item) {
    return String(
      item?.id ??
      item?.product_id ??
      item?.material_id ??
      item?.materialId ??
      item?.code ??
      item?.item_code ??
      item?.itemCode ??
      item?.name ??
      ""
    ).trim().toLowerCase();
  }

  function transactionType(t) {
    return String(
      t?.type ??
      t?.transaction_type ??
      t?.transactionType ??
      ""
    ).trim().toUpperCase();
  }

  function transactionQty(t) {
    return number(
      t?.quantity ??
      t?.qty ??
      t?.quantity_in ??
      t?.quantity_out ??
      0
    );
  }

  function calculateProduct(product, transactions) {
    const productId = idOf(product);

    const initial = number(
      product?.initial_stock ??
      product?.initialStock ??
      product?.opening_stock ??
      product?.openingStock ??
      product?.stock ??
      0
    );

    let stockIn = 0;
    let stockOut = 0;

    for (const t of transactions) {
      if (idOf(t) !== productId) continue;

      const type = transactionType(t);
      const qty = transactionQty(t);

      if (type === "IN" || type === "STOCK_IN" || type === "RECEIVE") {
        stockIn += qty;
      }

      if (type === "OUT" || type === "STOCK_OUT" || type === "ISSUE" || type === "SALE") {
        stockOut += qty;
      }
    }

    const current = initial + stockIn - stockOut;

    const reorder = number(
      product?.minimum_stock ??
      product?.minimumStock ??
      product?.reorder_level ??
      product?.reorderLevel ??
      product?.min_stock ??
      0
    );

    let status = "OK";

    if (current <= 0) {
      status = "OUT OF STOCK";
    } else if (current <= reorder) {
      status = "LOW STOCK";
    }

    return {
      initial,
      stockIn,
      stockOut,
      current,
      status
    };
  }

  function calculateAll() {
    const products = read("products_store", []);
    const transactions = read("transactions_store", []);

    if (!Array.isArray(products)) return [];

    return products.map(product => ({
      product,
      ...calculateProduct(product, Array.isArray(transactions) ? transactions : [])
    }));
  }

  function refresh() {
    const result = calculateAll();

    /*
     * Keep compatibility with existing Storeman renderer.
     * We expose calculated data without destroying existing records.
     */
    window.StoremanCalculatedStock = result;

    try {
      if (typeof window.renderUI === "function") {
        window.renderUI();
      }
    } catch (_) {}

    return result;
  }

  window.StoremanInventoryCalc = {
    calculate: calculateProduct,
    calculateAll,
    refresh
  };

  document.addEventListener("DOMContentLoaded", function () {
    try {
      refresh();
    } catch (_) {}
  });

})();
