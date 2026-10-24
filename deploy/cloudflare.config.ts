import { defineConfig } from "cf/config";

// Static-assets Worker serving the restored player in ../site
export default defineConfig({
	worker: {
		name: "ocean-of-thought",
		compatibilityDate: "2026-10-01",
		assets: {
			notFoundHandling: "none",
		},
		domains: ["oceanofthought.com", "www.oceanofthought.com", "oot.kschzt.com"],
		workersDev: false,
	},
});
