import { defineConfig } from "cf/config";

// Static-assets Worker serving the restored player in ../site at oot.kschzt.com
export default defineConfig({
	worker: {
		name: "ocean-of-thought",
		compatibilityDate: "2026-10-01",
		assets: {
			notFoundHandling: "none",
		},
		domains: ["oot.kschzt.com"],
		workersDev: false,
	},
});
