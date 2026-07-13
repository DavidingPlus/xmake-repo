const fs = require("fs");
const path = require("path");


function updateVersionFile(file, version, digest) {
    let lines = [];

    if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, "utf8");

        lines = content
            .split("\n")
            .filter(Boolean);
    }

    let updated = false;
    let found = false;

    lines = lines.map(line => {
        const [oldVersion, oldDigest] = line.split(/\s+/);

        if (oldVersion === version) {
            found = true;

            if (oldDigest !== digest) {
                updated = true;
                return `${version} ${digest}`;
            }

            return line;
        }

        return line;
    });


    // 新版本。
    if (!found) {
        lines.push(`${version} ${digest}`);
        updated = true;
    }

    if (updated) {
        fs.writeFileSync(
            file,
            lines.join("\n") + "\n"
        );

        console.log(`updated ${file}`);
    } else {
        console.log(`unchanged ${file}`);
    }
}


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

        updateVersionFile(
            file,
            version,
            digest
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
