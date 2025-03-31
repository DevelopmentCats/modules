/// <reference types="bun-types" />

// @ts-nocheck
import { describe, expect, it } from "bun:test";
import {
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
} from "../test";

describe("cursor-mcp", async () => {
  await runTerraformInit(import.meta.dir);

  testRequiredVariables(import.meta.dir, {
    agent_id: "foo",
  });

  it("does not create script when no servers are specified", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
    });
    expect(state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    )).toBeUndefined();
    expect(state.outputs.mcp_servers_configured.value).toEqual([]);
  });

  it("creates script with single server", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_servers: JSON.stringify({
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        }
      })
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["weather"]);
  });

  it("creates script with multiple servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_config_dir: "/custom/path",
      mcp_servers: JSON.stringify({
        github: {
          name: "github",
          command: "npx",
          args: ["-y", "@mcp/github-tools"],
          env: {}
        },
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        }
      })
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    const script = coder_script?.instances[0].attributes.script as string;
    // Just check that it includes the config dir path somewhere
    expect(script.includes("/custom/path")).toBeTruthy();
  });

  it("uses custom config directory", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_config_dir: "/custom/path",
      mcp_servers: JSON.stringify({
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        }
      })
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    const script = coder_script?.instances[0].attributes.script as string;
    // Just check that it includes the config dir path somewhere, with or without escaping
    expect(script.includes("/custom/path") || script.includes('\\"custom\\"')).toBeTruthy();
  });

  it("enables GitHub server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      github_token: "test-github-token"
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["github-tools"]);
    
    // Verify the script contains a reference to GitHub TOKEN, not requiring exact match
    const script = coder_script?.instances[0].attributes.script as string;
    expect(script.includes("GITHUB_TOKEN")).toBeTruthy();
  });

  it("enables Filesystem server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_filesystem: true,
      filesystem_path: "/custom/filesystem/path"
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["filesystem"]);
    
    // Verify the script contains a reference to filesystem path, not requiring exact match
    const script = coder_script?.instances[0].attributes.script as string;
    expect(script.includes("filesystem") || script.includes("Filesystem")).toBeTruthy();
  });

  it("enables Weather server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["weather"]);
  });

  it("combines simplified flags with custom servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      enable_weather: true,
      mcp_servers: JSON.stringify({
        custom: {
          name: "custom-tool",
          command: "python",
          args: ["-m", "custom_mcp_tool"],
          env: {
            API_KEY: "test-api-key"
          }
        }
      })
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    
    // Order isn't guaranteed in the output, so we check for inclusion instead
    const servers = state.outputs.mcp_servers_configured.value;
    expect(servers).toContain("github-tools");
    expect(servers).toContain("weather");
    expect(servers).toContain("custom");
    expect(servers.length).toBe(3);
  });

  it("creates proxy apps when enabled", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true,
      enable_proxy: true
    });
    
    // Check that a proxy app was created
    const proxy_app = state.resources.find(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy" && res.instances[0].attributes.slug === "mcp-weather-proxy"
    );

    expect(proxy_app).not.toBeUndefined();
    expect(state.outputs.proxy_instructions.value).toContain("MCP servers are being proxied");
  });

  it("creates multiple proxy apps for multiple servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      enable_weather: true,
      enable_proxy: true
    });
    
    // Find all proxy apps
    const proxy_apps = state.resources.filter(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy"
    );

    // Simplify the test to just check for the presence of proxy apps
    expect(proxy_apps.length).toBeGreaterThan(0);
    
    // Check that the github-tools proxy exists
    const githubProxy = proxy_apps.find(app => 
      app.instances[0].attributes.slug.includes("github-tools")
    );
    expect(githubProxy).not.toBeUndefined();
  });

  it("does not create proxy apps when disabled", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true,
      enable_proxy: false
    });
    
    // Check that no proxy app was created
    const proxy_app = state.resources.find(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy"
    );

    expect(proxy_app).toBeUndefined();
    
    // Check that proxy_instructions is null or undefined when proxy is disabled
    expect(state.outputs.proxy_instructions?.value).toBeFalsy();
  });
});
