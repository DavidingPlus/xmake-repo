const fs = require("fs");
const path = require("path");


async function main() {
    const payload = JSON.parse(process.env.CLIENT_PAYLOAD);
    const packageName = payload.package;
    const sourceRepo = payload.repo.split("/");
    const owner = sourceRepo[0];
    const repo = sourceRepo[1];
    const tag = payload.version;
    const version = tag.replace(/^v/, "");

    console.log(
        `Updating ${packageName} ${version}`
    );

    const octokit = require("@octokit/rest");

    const github = new octokit.Octokit({
        auth: process.env.GITHUB_TOKEN
    });


    /*
     * 获取 Release。
     */
    const release =
        await github.rest.repos.getReleaseByTag({
            owner,
            repo,
            tag
        });

    /*
     * versions 目录。
     */
    const versionDir =
        path.join(
            "packages",
            packageName[0],
            packageName,
            "versions"
        );

    /*
     * asset 名称映射。
     */
    function getVersionFile(name) {
        if (name.includes("linux-arm64")) return "linux-arm64.txt";
        if (name.includes("linux-x86_64")) return "linux-x86_64.txt";
        if (name.includes("windows-x64-MDd")) return "windows-x64-MDd.txt";
        if (name.includes("windows-x64-MD")) return "windows-x64-MD.txt";

        return null;
    }

    for (const asset of release.data.assets) {
        const versionFile = getVersionFile(asset.name);
        if (!versionFile) continue;

        const digest = asset.digest.replace(
            "sha256:",
            ""
        );

        const file = path.join(
            versionDir,
            versionFile
        );

        const line = `${version} ${digest}\n`;

        fs.appendFileSync(
            file,
            line
        );

        console.log(
            `updated ${file}`
        );
    }
}


main().catch(err => {
    console.error(err);
    process.exit(1);
});
